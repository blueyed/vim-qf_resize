let s:has_win_getid = exists('*win_getid')
let s:has_new_api = exists('*win_screenpos') || exists('*nvim_win_get_position')
let s:degraded = has('patch-8.0.0677') && !s:has_new_api

if s:degraded && !get(g:, 'qf_resize_no_warning', 0)
  echohl WarningMsg
  echom 'qf_resize: paritally degraded due to using Vim 8.0.0677-8.0.1364 (set g:qf_resize_no_warning=1 to skip this warning).'
  echohl None
endif

" Get max height, based on g:/b:qf_resize_max_ratio.
function! qf_resize#get_maxheight(height) abort
  let ratio = get(b:, 'qf_resize_max_ratio', get(g:, 'qf_resize_max_ratio', 0.15))
  let maxheight = float2nr(round(a:height * ratio))
  return maxheight
endfunction

function! s:logging_enabled() abort
  return exists('*vader#log') || &verbose || get(g:, 'qf_resize_debug', 0)
endfunction

function! s:log(msg) abort
  if exists('*vader#log')
    call vader#log(a:msg)
    call insert(get(g:, 'qf_resize_test_messages', []), a:msg)
  elseif &verbose || get(g:, 'qf_resize_debug', 0)
    unsilent echom 'qf_resize: '.a:msg
  endif
endfunction

if exists('*win_screenpos')
  function! s:get_win_col(winid) abort
    return win_screenpos(a:winid)[1]
  endfunction

elseif exists('*nvim_win_get_position')
  function! s:get_win_col(winid) abort
    return nvim_win_get_position(a:winid)[1] + 1
  endfunction
endif

if exists('*nvim_buf_line_count')
  function! s:get_line_count(winnr) abort
    return nvim_buf_line_count(winbufnr(a:winnr))
  endfunction
else
  function! s:get_line_count(winnr) abort
    " XXX: optimize?! should not fetch the whole list!
    return a:winnr == winnr() ? line('$') : len(getbufline(winbufnr(a:winnr), 1, '$'))
  endfunction
endif

if s:has_new_api
  function! qf_resize#_get_possible_nonfixed_above(winnr) abort
    let lines = max([1, s:get_line_count(a:winnr)])
    if a:winnr == 1
      return [[], [], lines]
    endif

    let winid = win_getid(a:winnr)

    let qfs_above = []
    let cur_width = winwidth(a:winnr)
    let cur_col = s:get_win_col(winid)
    let possible_non_fixed_above = []
    let w = a:winnr
    while w > 1
      let w -= 1
      let w_col = s:get_win_col(win_getid(w))

      " Same column means that it might be above (depending on splitting).
      if w_col >= cur_col && w_col <= cur_col + cur_width
        if !getwinvar(w, '&winfixheight')
          let possible_non_fixed_above += [w]
        elseif getwinvar(w, '&filetype') ==# 'qf'
          let qfs_above += [w]
        endif
      endif
    endwhile
    return [possible_non_fixed_above, qfs_above, lines]
  endfunction

elseif has('patch-8.0.0677')
  " Intermediate: no new API, but patch v8.0.0677 disallows 'wincmd k' in
  " FileType autocommands.  This method returns windows only according to the
  " index.
  function! qf_resize#_get_possible_nonfixed_above(winnr) abort
    let lines = s:get_line_count(a:winnr)
    if a:winnr == 1
      return [[], [], lines]
    endif
    let qfs_above = []
    let w = a:winnr
    let possible_non_fixed_above = []
    while w > 1
      let w -= 1
      if !getwinvar(w, '&winfixheight')
        let possible_non_fixed_above += [w]
      elseif getwinvar(w, '&filetype') ==# 'qf'
        let qfs_above += [w]
      endif
    endwhile
    return [possible_non_fixed_above, qfs_above, lines]
  endfunction

else
  " Fallback: use 'wincmd k' to get windows above (original method).
  function! qf_resize#_get_possible_nonfixed_above(winnr) abort
    let restore = winnr()
    try
      if a:winnr != restore
        exe 'keepalt noautocmd' a:winnr 'wincmd w'
      endif
      let lines = s:get_line_count(a:winnr)
      if a:winnr == 1
        return [[], [], lines]
      endif
      let qfs_above = []
      let possible_non_fixed_above = []
      let prev_winnr = a:winnr
      while 1
        exe 'noautocmd wincmd k'
        let w = winnr()
        if w == prev_winnr
          break
        endif
        if !getwinvar(w, '&winfixheight')
          let possible_non_fixed_above += [w]
        elseif getwinvar(w, '&filetype') ==# 'qf'
          let qfs_above += [w]
        endif
        let prev_winnr = w
      endwhile
    finally
      if winnr() != restore
        exe 'keepalt noautocmd' restore 'wincmd w'
      endif
    endtry
    return [possible_non_fixed_above, qfs_above, lines]
  endfunction
endif

let s:prev_windows = []
function! s:save_prev_windows() abort
  let aw = winnr('#')
  let pw = winnr()
  if exists('*win_getid')
    let aw_id = win_getid(aw)
    let pw_id = win_getid(pw)
  else
    let aw_id = 0
    let pw_id = 0
  endif
  call add(s:prev_windows, [aw, pw, aw_id, pw_id])
endfunction

function! s:restore_prev_windows() abort
  let [aw, pw, aw_id, pw_id] = remove(s:prev_windows, 0)
  if winnr() != pw
    " Go back, maintaining the '#' window (CTRL-W_p).
    if pw_id
      let aw = win_id2win(aw_id)
      let pw = win_id2win(pw_id)
    endif
    if pw
      if aw
        exec aw . 'wincmd w'
      endif
      exec pw . 'wincmd w'
    endif
  endif
endfunction

" @vimlint(EVL102, 1, l:wincnt)
function! s:get_window_layout_str() abort
  let wincnt = winnr('$')
  return join(map(range(1, winnr('$')),
          \   "v:val.'/'.wincnt.': ['."
          \  ."'ft='.getwinvar(v:val, '&filetype'). "
          \  ."', bt='.getwinvar(v:val, '&buftype'). "
          \  ."', height='.winheight(v:val).']'"), '; ')
endfunction
" @vimlint(EVL102, 0, l:wincnt)

" Ignore may-not-be-initialized warnings - pretty bad, but ok for now.
" @vimlint(EVL104, 1, l:left_window)
" @vimlint(EVL104, 1, l:height)
" @vimlint(EVL104, 1, l:non_fixed_above_height)
" cur_win (a:1) should be a window Id if win_getid() exists, otherwise winnr.
function! qf_resize#adjust_window_height(...) abort
  if a:0
    let cur_win = a:1
  else
    let cur_win = s:has_win_getid ? win_getid() : winnr()
  endif
  if s:logging_enabled()
    call s:log(printf('Called for window %s (title=%s); layout: [%s]',
          \ cur_win . (s:has_win_getid ? ' ('.win_id2win(cur_win).')' : ''),
          \ get(w:, 'quickfix_title', ''),
          \ s:get_window_layout_str()))
  endif
  if exists('*win_getid')
    let winnr = win_id2win(cur_win)
    if winnr == 0
      call s:log(printf('no window found for ID %d', cur_win))
      return
    else
      call s:log(printf('using winnr=%d for winid %d', winnr, cur_win))
    endif
  else
    let winnr = cur_win
    if winnr > winnr('$')
      call s:log(printf('window %d does not exist', winnr))
      return
    endif
  endif

  let bufnr = winbufnr(winnr)

  if !getbufvar(bufnr, '_qf_resize_seen')
    call setbufvar(bufnr, '_qf_resize_seen', 1)
    let is_loc = !empty(getloclist(0))
    call setbufvar(bufnr, '_qf_resize_isLoc', is_loc)
    let qf_window_appeared = 1
    if !has_key(s:tracked_heights, 'WinEnter')
          \ || s:tracked_heights['WinEnter'][0] != winnr()
      " Happens when using 'noautocmd lopen', or :lopen being used from a
      " non-nested autocommand.
      let qf_window_appeared = 0
    else
      let left_window = s:tracked_heights['WinLeave'][0]
    endif
  else
    let qf_window_appeared = 0
  endif

  " Get minimum height (given more lines than that).
  let minheight = get(b:, 'qf_resize_min_height', get(g:, 'qf_resize_min_height', -1))
  if minheight == -1
    " Some opinionated defaults.
    if !empty(getbufvar(bufnr, 'dispatch'))
      " dispatch.vim
      let minheight = 15
    elseif getwinvar(winnr, 'quickfix_title') =~# '\v^:.*py.?test'
      " test.vim, running pytest.
      let minheight = max([5, &lines/5])
    else
      let minheight = 1
    endif
  endif

  let [possible_non_fixed_above, qfs_above, lines] = qf_resize#_get_possible_nonfixed_above(winnr)
  if empty(possible_non_fixed_above)
    call s:log('no non-qf window above')
    return 0
  endif

  let maxheight = get(b:, 'qf_resize_max_height', get(g:, 'qf_resize_max_height', 10))
  let cur_qf_height = winheight(cur_win)

  let non_fixed_above = -1

  if qf_window_appeared && index(possible_non_fixed_above, left_window) != -1
    let non_fixed_above = left_window
    let height = s:tracked_heights['WinLeave'][1] + s:tracked_heights['WinEnter'][1] + 1
    let non_fixed_above_height = winheight(non_fixed_above)
  elseif !s:degraded
    let non_fixed_above = possible_non_fixed_above[0]
    let non_fixed_above_height = winheight(non_fixed_above)
    let height = non_fixed_above_height + cur_qf_height + 1
  else
    call s:log('could not determine non-qf window above')
    if &lines - cur_qf_height - &cmdheight < 5
      " This means/assumes that the qf window is in a column by itself.
      call s:log('skipping simple resize due to qf window being in a column by itself likely')
      return
    endif
  endif
  if non_fixed_above > 0
    let maxheight = min([maxheight, qf_resize#get_maxheight(height)])
  endif

  let maxheight = max([minheight, maxheight])
  let qf_height = min([maxheight, lines])
  let diff = qf_height - cur_qf_height
  call s:log(printf('maxheight: %d, minheight: %d, lines: %s, cur_qf_height: %d, qf_height: %d, diff: %d',
        \ maxheight, minheight, lines, cur_qf_height, qf_height, diff))
  if diff == 0
    call s:log('no diff')
  else
    let cmd = winnr.' resize '.qf_height
    call s:log('resizing (1): '.cmd)
    exe cmd

    if qf_window_appeared && non_fixed_above == s:tracked_heights['WinLeave'][0]
      let old_size = s:tracked_heights['WinLeave'][1] + s:tracked_heights['WinEnter'][1] - qf_height
      call s:log('resizing non_fixed_above: '.non_fixed_above.' resize '.old_size)
      exe non_fixed_above.'resize '.old_size
      let s:tracked_heights = {}
    elseif non_fixed_above != -1
      let above_new_height = non_fixed_above_height - diff
      if above_new_height != winheight(non_fixed_above)
        call s:log('resizing non_fixed_above (2): '.non_fixed_above.' resize '.above_new_height)
        exe non_fixed_above.'resize '.above_new_height
      endif
    endif
  endif

  " Need to handle other qf windows above.
  if !empty(qfs_above)
    call qf_resize#adjust_window_heights(qfs_above)
  endif
  return diff
endfunction
" @vimlint(EVL104, 0, l:left_window)
" @vimlint(EVL104, 0, l:height)
" @vimlint(EVL104, 0, l:non_fixed_above_height)

function! qf_resize#adjust_window_heights(...) abort
  if a:0
    let windows = a:1
  else
    if has('vim_starting') && !exists('g:vader_file')
      return
    endif

    if get(w:, 'quickfix_title', '') =~# '\v^:noautocmd cgetfile '
      " Skipping dispatch, will be done through user autocmd (DispatchQuickfix).
      return
    endif

    let windows = []
    for w in reverse(range(1, winnr('$')))
      if getwinvar(w, '&ft') ==# 'qf'
        let windows += [w]
      endif
    endfor
  endif
  if empty(windows)
    return
  endif

  let changed = 0
  let max_loops = 3
  call s:save_prev_windows()
  try
    " Loop until there are no changes anymore.
    while max_loops
      let max_loops -= 1
      for w in windows
        let height_before = winheight(w)
        if exists('*win_getid')
          let w = win_getid(w)
        endif
        noautocmd let cur_changed = qf_resize#adjust_window_height(w) != 0
        if cur_changed
          redraw
          let changed = 1
        endif
        if !changed
          let changed = height_before != winheight(w)
        endif
      endfor
      if !changed
        break
      endif
      let changed = 0
    endwhile
    if !max_loops
      echom 'Note: max_loops reached in s:adjust_window_heights()'
    endif
  finally
    call s:restore_prev_windows()
  endtry
endfunction

function! qf_resize#adjust_on_winquit() abort
  if get(t:, '_qf_resize_win_count', 0) > winnr('$')
    call qf_resize#adjust_window_heights()
  endif
  let t:_qf_resize_win_count = winnr('$')
endfunction

let s:tracked_heights = {}
function! qf_resize#track_heights(event) abort
  if a:event ==# 'WinEnter'
    if get(s:tracked_heights, 'WinLeave', [0, 0])[0] != winnr('#')
      " WinEnter did not follow WinLeave for a new window.
      let s:tracked_heights = {}
    else
      let s:tracked_heights['WinEnter'] = [winnr(), winheight(0)]
    endif
  else
    let s:tracked_heights = {'WinLeave': [winnr(), winheight(0)]}
  endif
  call s:log(printf('tracked_heights: %s (#%d): %s',
        \ a:event, winnr(), string(s:tracked_heights)))
endfunction

function! qf_resize#on_QuickFixCmdPost() abort
  let buf = expand('<abuf>')
  let cmd = expand('<amatch>')
  call s:log(printf('QuickFixCmdPost: amatch=%s, buf=%d, winnr=%d, ft=%s, layout=%s', cmd, buf, winnr(), &filetype, s:get_window_layout_str()))
  if empty(cmd)
    return
  endif
  let winid = 0
  if cmd[0] ==# 'c'
    let winid = get(getqflist({'winid': 1}), 'winid', 0)
  else
    let winid = get(getloclist(0, {'winid': 1}), 'winid', 0)
  endif
  if winid
    call qf_resize#adjust_window_height(winid)
  endif
endfunction
