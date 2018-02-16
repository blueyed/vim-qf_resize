" Get max height, based on g:/b:qf_resize_max_ratio.
function! qf_resize#get_maxheight(height) abort
  let ratio = get(b:, 'qf_resize_max_ratio', get(g:, 'qf_resize_max_ratio', 0.15))
  let maxheight = float2nr(round(a:height * ratio))
  return maxheight
endfunction

function! s:log(msg) abort
  if exists('*vader#log')
    call vader#log(a:msg)
  elseif &verbose || get(g:, 'qf_resize_debug', 0)
    echom 'adjust_window_height: '.a:msg
  endif
endfunction

function! s:get_nonfixed_above(win) abort
  if a:win == 1
    return [0, [], line('$')]
  endif
  let qfs_above = []
  let restore = winnr()
  try
    if a:win != restore
      exe 'keepalt noautocmd' a:win 'wincmd w'
    endif
    let lines = line('$')
    let prev_winnr = a:win
    while 1
      exe 'noautocmd wincmd k'
      let w = winnr()
      if w == prev_winnr
        return [0, qfs_above, lines]
      endif
      if !&winfixheight
        return [w, qfs_above, lines]
      endif
      if &filetype ==# 'qf'
        let qfs_above += [w]
      endif
      let prev_winnr = w
    endwhile
  finally
    if winnr() != restore
      exe 'keepalt noautocmd' restore 'wincmd w'
    endif
  endtry
endfunction

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

function! qf_resize#adjust_window_height(...) abort
  let cur_win = a:0 ? a:1 : winnr()
  call s:log('Called for window '.cur_win
        \ .'; window layout: '.string(map(range(1, winnr('$')), 'winheight(v:val)')))
  if cur_win > winnr('$') || cur_win < 1
    return
  endif

  if !exists('b:_qf_resize_seen')
    let b:_qf_resize_seen = 1
    let qf_window_appeared = 1
    if !has_key(s:tracked_heights, 'WinEnter')
          \ || s:tracked_heights['WinEnter'][0] != winnr()
      " Happens when using 'noautocmd lopen', or :lopen being used from a
      " non-nested autocommand.
      let qf_window_appeared = 0
    endif
  else
    let qf_window_appeared = 0
  endif

  " Get first non-qf window above.
  let [non_fixed_above, qfs_above, lines] = s:get_nonfixed_above(cur_win)

  " Get minimum height (given more lines than that).
  let minheight = get(b:, 'qf_resize_min_height', get(g:, 'qf_resize_min_height', -1))
  if minheight == -1
    " Some opinionated defaults.
    if exists('b:dispatch')
      " dispatch.vim
      let minheight = 15
    elseif getwinvar(cur_win, 'quickfix_title') =~# '\v^:.*py.?test'
      " test.vim, running pytest.
      let minheight = max([5, &lines/5])
    else
      let minheight = 1
    endif
  endif

  let cur_qf_height = winheight(cur_win)
  let maxheight = get(b:, 'qf_resize_max_height', get(g:, 'qf_resize_max_height', 10))
  if non_fixed_above
    let non_fixed_above_height = winheight(non_fixed_above)

    if qf_window_appeared && non_fixed_above == s:tracked_heights['WinLeave'][0]
      let height = s:tracked_heights['WinLeave'][1] + s:tracked_heights['WinEnter'][1] + 1
    else
      let height = non_fixed_above_height + cur_qf_height + 1
    endif
    let maxheight = min([maxheight, qf_resize#get_maxheight(height)])
  else
    call s:log('no non-qf window above')
    return 0
  endif
  let maxheight = max([minheight, maxheight])
  let qf_height = min([maxheight, lines])
  let diff = qf_height - cur_qf_height
  call s:log(printf('maxheight: %d, minheight: %d, lines: %s, cur_qf_height: %d, diff: %d', maxheight, minheight, lines, cur_qf_height, diff))
  if diff == 0
    call s:log('no diff')
  else
    call s:log('resizing (1): '.cur_win.' resize '.qf_height)
    exe cur_win 'resize' qf_height

    if qf_window_appeared && non_fixed_above == s:tracked_heights['WinLeave'][0]
      let old_size = s:tracked_heights['WinLeave'][1] + s:tracked_heights['WinEnter'][1] - qf_height
      call s:log('resizing non_fixed_above: '.non_fixed_above.' resize '.old_size)
      exe non_fixed_above.'resize '.old_size
      let s:tracked_heights = {}
    else
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
        exe 'keepalt noautocmd' w 'wincmd w'
        noautocmd let cur_changed = qf_resize#adjust_window_height() != 0
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
  call s:log(string(map(range(1, winnr('$')), 'winheight(v:val)')))
endfunction
