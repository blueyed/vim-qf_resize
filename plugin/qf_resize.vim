if exists('g:loaded_qf_resize')
  finish
endif
let g:loaded_qf_resize = 1

if !exists('g:qf_resize_use_feedkeys')
  let g:qf_resize_use_feedkeys = has('patch-8.0.0677')
endif

augroup qf_resize
  au!
  if g:qf_resize_use_feedkeys
    " Workaround: E788: Not allowed to edit another buffer now
    au FileType   qf call feedkeys("\<C-\>\<C-n>:call qf_resize#adjust_window_height(".winnr().")\n", 'n')
  else
    au FileType   qf call qf_resize#adjust_window_height()
  endif
  au VimResized *  call qf_resize#adjust_window_heights()

  if get(g:, 'qf_resize_on_win_close', 1)
    au WinEnter * call qf_resize#adjust_on_winquit()
  endif

  " Track heights of previous/new window with :lopen etc.
  au WinLeave * call qf_resize#track_heights('WinLeave')
  au WinEnter * call qf_resize#track_heights('WinEnter')

  " For dispatch: handle other qf's after successful run.
  " Handle all windows, otherwise a location list might be too high.
  " au QuickFixCmdPost cgetfile call AdjustWindowHeights('QuickFixCmdPost')
  " Requires: https://github.com/tpope/vim-dispatch/pull/186.
  au User DispatchQuickfix call qf_resize#adjust_window_heights()
augroup END

command! QfResizeWindows call qf_resize#adjust_window_heights()
