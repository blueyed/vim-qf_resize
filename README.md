# vim-qf_resize

Automatically resize quickfix and location list windows.

This Vim plugin resizes location/quickfix windows based on the number of lines
therein, i.e. with a single list entry, why waste 9 extra lines (with the
default window height being 10)?!

## Config

### `g:qf_resize_min_height`

Minimum height (in lines) for quickfix windows.
If not specified, it will use some (experimental) internal defaults, falling
back to 1.
Can be a buffer setting (for the qf buffer).

### `g:qf_resize_max_height`

Maximum height (in lines) for quickfix windows.  Default: 10.
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

## Related plugins

- [vim-qf](https://github.com/romainl/vim-qf) provides a similar feature
  (`g:qf_auto_resize`), without handling `:lopen`/`:copen` etc in general,
  but only when opening windows itself, and is less advanced in general (no
  ratio etc).
