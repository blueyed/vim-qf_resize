" Get max height, based on g:/b:qf_resize_max_ratio.
function! qf_resize#get_maxheight(height) abort
  let ratio = get(b:, 'qf_resize_max_ratio', get(g:, 'qf_resize_max_ratio', 0.15))
  let maxheight = float2nr(round(a:height * ratio))
  return maxheight
endfunction
