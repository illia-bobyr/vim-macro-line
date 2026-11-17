" vim-macro-line: keep Vim macros as readable lines inside the files they work
" on.
" Maintainer: Illia Bobyr
" License:    MIT, see LICENSE.

if exists('g:loaded_macro_line') || &compatible
  finish
endif
let g:loaded_macro_line = 1

let s:save_cpo = &cpo
set cpo&vim

command! -bang -range -register MacroPut
      \ call macro_line#put(<q-reg>, <line2>, <bang>0)
command! -range -register MacroLoad
      \ call macro_line#load(<line1>, <line2>, <q-reg>)
command! -range -register MacroUpdate
      \ call macro_line#update(<line2>, <q-reg>)

nnoremap <silent> <Plug>(macro-line-put)
      \ :<C-u>call macro_line#put(macro_line#map_register(), line('.'), 0)<CR>
nnoremap <silent> <Plug>(macro-line-put-above)
      \ :<C-u>call macro_line#put(macro_line#map_register(), line('.'), 1)<CR>
nnoremap <silent> <Plug>(macro-line-load)
      \ :<C-u>call macro_line#load(line('.'), line('.') + v:count1 - 1,
      \ macro_line#map_register())<CR>
xnoremap <silent> <Plug>(macro-line-load)
      \ :<C-u>call macro_line#load(line("'<"), line("'>"),
      \ macro_line#map_register())<CR>
nnoremap <silent> <Plug>(macro-line-update)
      \ :<C-u>call macro_line#update(line('.'), macro_line#map_register())<CR>

" Binds `lhs` to `plug` in `mode`, unless the user already mapped `plug`
" somewhere, or `lhs` is already taken by another mapping.  An empty `lhs`
" disables it.
function! s:map(mode, lhs, plug) abort
  if a:lhs ==# '' || hasmapto(a:plug, a:mode) || maparg(a:lhs, a:mode) !=# ''
    return
  endif
  execute a:mode . 'map' a:lhs a:plug
endfunction

if !get(g:, 'macro_line_no_mappings', 0) && !get(g:, 'no_plugin_maps', 0)
  call s:map('n', get(g:, 'macro_line_put_map', '<Leader>mp'),
        \ '<Plug>(macro-line-put)')
  call s:map('n', get(g:, 'macro_line_put_above_map', '<Leader>mP'),
        \ '<Plug>(macro-line-put-above)')
  call s:map('n', get(g:, 'macro_line_load_map', '<Leader>ml'),
        \ '<Plug>(macro-line-load)')
  call s:map('x', get(g:, 'macro_line_load_map', '<Leader>ml'),
        \ '<Plug>(macro-line-load)')
  call s:map('n', get(g:, 'macro_line_update_map', '<Leader>mu'),
        \ '<Plug>(macro-line-update)')
endif

let &cpo = s:save_cpo
unlet s:save_cpo
