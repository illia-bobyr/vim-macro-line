" vim-macro-line: keep Vim macros as readable lines inside the files they work
" on.
" Maintainer: Illia Bobyr
" License:    MIT, see LICENSE.

let s:save_cpo = &cpo
set cpo&vim

" Registers a macro line may name.  Read-only registers (. : % #) and the
" expression register (=) are excluded.
let s:reg_chars = '[a-zA-Z0-9"*+/-]'

" A "..." Vim string literal.
let s:literal = '"\%([^"\\]\|\\.\)*"'

" `let @r = "..."`.  Group 1 is the register, group 2 the literal.  Anything
" around it -- a comment leader, backticks, prose -- is ignored.
let s:prefix = '\C\<let\s\+@\(' . s:reg_chars . '\)\s*=\s*'
let s:macro_line = s:prefix . '\(' . s:literal . '\)'

" `keytrans()` names a few keys that read better as plain characters inside a
" "..." string.
let s:plain_keys = {'Space': ' ', 'Bar': '|', 'Bslash': '\\', 'lt': '<'}

let s:default_templates = {'': '%s', 'text': '%s', 'markdown': '`%s`'}

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'macro-line: ' . substitute(a:msg, '^macro-line: ', '', '')
  echohl None
endfunction

function! s:token(name) abort
  return get(s:plain_keys, a:name, '\<' . a:name . '>')
endfunction

function! s:valid_register(reg) abort
  return a:reg =~# '^' . s:reg_chars . '$'
endfunction

" Returns {keys} -- the raw content of a register -- as a "..." string literal
" in <> key notation, e.g. "0f D\<Esc>j".  Throws when {keys} holds bytes that
" can not be written that way (invalid UTF-8).
function! macro_line#encode(keys) abort
  if !exists('*keytrans')
    throw 'macro-line: keytrans() is missing, Vim 9.0 or Neovim 0.8 is required'
  endif
  " keytrans() already turns \ | < into <Bslash> <Bar> <lt>, so only " is
  " left to escape.  \ is escaped too, in case some version keeps it as is.
  let l:text = escape(keytrans(a:keys), '"\')
  let l:text = substitute(l:text, '<\([^<>]\+\)>', '\=s:token(submatch(1))', 'g')
  let l:literal = '"' . l:text . '"'
  if eval(l:literal) !=# a:keys
    throw 'macro-line: the macro contains bytes that can not be written'
          \ . ' in key notation'
  endif
  return l:literal
endfunction

" Returns the keys a "..." string {literal} stands for.  Only a plain string
" literal is accepted, so nothing taken from a file is ever executed.
function! macro_line#decode(literal) abort
  if a:literal !~# '^' . s:literal . '$'
    throw 'macro-line: not a "..." string: ' . a:literal
  endif
  return eval(a:literal)
endfunction

" Returns the `let @r = "..."` text for register {reg}.
function! macro_line#format(reg) abort
  return 'let @' . a:reg . ' = ' . macro_line#encode(getreg(a:reg))
endfunction

" Finds the first macro on {line}.  Returns {} when there is none, otherwise
" a dict with:
"   register  the register name after "@"
"   literal   the "..." string, as written
"   start     byte index of the literal in {line}
"   end       byte index just past the literal
function! macro_line#parse(line) abort
  let l:m = matchlist(a:line, s:macro_line)
  if empty(l:m)
    return {}
  endif
  let l:start = match(a:line, s:prefix . '\zs' . s:literal)
  return {
        \ 'register': l:m[1],
        \ 'literal': l:m[2],
        \ 'start': l:start,
        \ 'end': l:start + len(l:m[2]),
        \ }
endfunction

" The register to save when none was given: g:macro_line_register, else the
" register last recorded into (reg_recorded(), Neovim only), else "q".
function! macro_line#default_register() abort
  let l:reg = get(g:, 'macro_line_register', '')
  if l:reg ==# '' && exists('*reg_recorded')
    let l:reg = reg_recorded()
  endif
  return l:reg ==# '' ? 'q' : l:reg
endfunction

" v:register, or '' when no register was typed before the mapping.
function! macro_line#map_register() abort
  let l:unnamed = &clipboard =~# '\<unnamedplus\>' ? '+'
        \ : &clipboard =~# '\<unnamed\>' ? '*' : '"'
  return v:register ==# l:unnamed ? '' : v:register
endfunction

" The template, with one "%s", that a new macro line is wrapped in.
function! s:template() abort
  if exists('b:macro_line_template')
    return b:macro_line_template
  endif
  let l:templates = extend(copy(s:default_templates),
        \ get(g:, 'macro_line_templates', {}))
  " "markdown.pandoc" falls back to "markdown".
  for l:ft in [&filetype, matchstr(&filetype, '^[^.]*')]
    if has_key(l:templates, l:ft)
      return l:templates[l:ft]
    endif
  endfor
  if &commentstring !~# '%s'
    return '%s'
  endif
  " "#%s" -> "# %s", "/*%s*/" -> "/* %s */".
  let l:cs = substitute(&commentstring, '\S\zs%s', ' %s', '')
  return substitute(l:cs, '%s\ze\S', '%s ', '')
endfunction

function! s:wrap(text) abort
  let l:template = s:template()
  " Markdown inline code: a ` in the macro needs a longer fence.
  if l:template ==# '`%s`' && stridx(a:text, '`') >= 0
    let l:template = '`` %s ``'
  endif
  return substitute(l:template, '%s', escape(a:text, '\&'), '')
endfunction

" Puts register {reg} ('' for the default) as a macro line below line {lnum},
" or above it when {above} is true, with the indent of line {lnum}.  Returns
" the number of the new line, or 0 on error.
function! macro_line#put(reg, lnum, above) abort
  let l:reg = a:reg ==# '' ? macro_line#default_register() : a:reg
  if !s:valid_register(l:reg)
    call s:error('can not save register ' . string(l:reg))
    return 0
  endif
  if getreg(l:reg) ==# ''
    call s:error('register ' . l:reg . ' is empty')
    return 0
  endif
  try
    " Lowercase: `let @A = ...` would append when loaded.
    let l:text = macro_line#format(tolower(l:reg))
  catch /^macro-line:/
    call s:error(v:exception)
    return 0
  endtry
  let l:indent = matchstr(getline(a:lnum), '^\s*')
  let l:after = a:above ? a:lnum - 1 : a:lnum
  call append(l:after, l:indent . s:wrap(l:text))
  call cursor(l:after + 1, len(l:indent) + 1)
  return l:after + 1
endfunction

" Loads every macro line in {line1}..{line2} into its register, or into {reg}
" when it is not ''.  Returns the list of registers set.
function! macro_line#load(line1, line2, reg) abort
  if a:reg !=# '' && !s:valid_register(a:reg)
    call s:error('can not load into register ' . string(a:reg))
    return []
  endif
  let l:loaded = []
  for l:lnum in range(a:line1, a:line2)
    let l:m = macro_line#parse(getline(l:lnum))
    if empty(l:m)
      continue
    endif
    let l:reg = a:reg ==# '' ? l:m.register : a:reg
    try
      let l:keys = macro_line#decode(l:m.literal)
      " Without an explicit type, setreg() and `:let @r` make a value that
      " ends in <CR> linewise, appending a NL.  Only a trailing NL means
      " linewise here, the way getreg() returns a linewise register.
      call setreg(l:reg, l:keys, l:keys =~# '\n$' ? 'l' : 'c')
    catch
      call s:error('line ' . l:lnum . ': ' . v:exception)
      continue
    endtry
    call add(l:loaded, l:reg)
  endfor
  if empty(l:loaded)
    call s:error(a:line1 == a:line2
          \ ? 'no macro on line ' . a:line1
          \ : 'no macros on lines ' . a:line1 . '-' . a:line2)
  elseif !get(g:, 'macro_line_quiet', 0)
    echo 'macro-line: loaded ' . join(map(copy(l:loaded), '"@" . v:val'), ', ')
  endif
  return l:loaded
endfunction

" Rewrites the macro on line {lnum} with the content of its register, or of
" {reg} when it is not ''.  The register named on the line and all text around
" the macro are kept.  Returns 1 on success, 0 on error.
function! macro_line#update(lnum, reg) abort
  let l:line = getline(a:lnum)
  let l:m = macro_line#parse(l:line)
  if empty(l:m)
    call s:error('no macro on line ' . a:lnum)
    return 0
  endif
  let l:reg = a:reg ==# '' ? l:m.register : a:reg
  if !s:valid_register(l:reg) || getreg(l:reg) ==# ''
    call s:error('register ' . l:reg . ' is empty')
    return 0
  endif
  try
    let l:literal = macro_line#encode(getreg(l:reg))
  catch /^macro-line:/
    call s:error(v:exception)
    return 0
  endtry
  if l:literal !=# l:m.literal
    call setline(a:lnum, strpart(l:line, 0, l:m.start) . l:literal
          \ . strpart(l:line, l:m.end))
  endif
  if !get(g:, 'macro_line_quiet', 0)
    echo 'macro-line: updated @' . l:m.register
          \ . (l:reg ==# l:m.register ? '' : ' from @' . l:reg)
  endif
  return 1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
