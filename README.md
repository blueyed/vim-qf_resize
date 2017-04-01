# vim-qf_resize

Automatically resize quickfix and location list windows.

It will resize location/quickfix windows based on the number of lines therein;
e.g. with a single list entry, why waste 10 lines (the default height)?!

With vim-test/dispatch-neovim etc., and on VimResized it will process all
existing qf windows.

## Config

### `g:qf_resize_min_height`

Minimum height in lines for qf windows.
If not specified, it will use some (experimental) internal defaults, falling
back to 1.
Can be a buffer setting (for the qf buffer).

### `g:qf_resize_max_height`

Maximum height in lines of qf windows.  Default: 10.
Can be a buffer setting (for the qf buffer).

### `g:qf_resize_max_ratio`

Ratio used to get the dynamic max height.
It gets multiplied with the sum of the height of the non-qf window and the
height of the qf window.  The default is `0.15`.
Can be a buffer setting (for the qf buffer).

### `g:qf_resize_on_win_close`

Resize/handle all qf windows when a window gets closed.  Default: 1.

## Commands

### `QfResizeWindows`

Resize all quickfix/location list windows on the current tab page.

This is useful in a custom mapping (extending the default
<kbd>Ctrl</kbd>-<kbd>w</kbd> <kbd>=</kbd>):

    nnoremap <silent> <c-w>= :wincmd =<cr>:QfResizeWindows<cr>
