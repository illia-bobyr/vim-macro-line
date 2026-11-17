" Tests for vim-macro-line.  Run with `make test`, or:
"   vim -Nu NONE -i NONE -es --cmd 'set rtp^=.' -S test/test.vim

set nocompatible
runtime plugin/macro_line.vim
let g:macro_line_quiet = 1
let mapleader = '\'

" Like assert_fails(), but the exception is caught, so `vim -es` still exits
" with 0 when every test passes.
function! s:assert_throws(cmd, pattern) abort
  try
    execute a:cmd
    call assert_report('no exception from: ' . a:cmd)
  catch
    call assert_match(a:pattern, v:exception, a:cmd)
  endtry
endfunction

function! s:reset(lines, ...) abort
  %bwipeout!
  enew!
  let &l:filetype = a:0 ? a:1 : ''
  call setline(1, a:lines)
  call cursor(1, 1)
endfunction

function! Test_round_trip() abort
  let l:cases = [
        \ "0f D\<Esc>j",
        \ "a\\b\"c<d>|e<lt>f`",
        \ "\<Esc>\<Left>\<C-a>\<CR>\t\<C-v>\<C-[>",
        \ "\<M-a>\<S-F3>\<C-Left>\<Cmd>echo 1\<CR>",
        \ "é中<Esc>",
        \ "yyp\n",
        \ "  leading and trailing  ",
        \ ]
  for l:keys in l:cases
    let l:literal = macro_line#encode(l:keys)
    call assert_equal(l:keys, macro_line#decode(l:literal), l:literal)
    call assert_equal(l:keys, eval(l:literal), 'sourceable: ' . l:literal)
  endfor
endfunction

function! Test_encode_readable() abort
  call assert_equal('"0f D\<Esc>j"', macro_line#encode("0f D\<Esc>j"))
  call assert_equal('"a|b\\c\"d<e>"', macro_line#encode('a|b\c"d<e>'))
  call assert_equal('"x<Esc>\<Esc>"', macro_line#encode("x<Esc>\<Esc>"))
endfunction

function! Test_encode_rejects_invalid_bytes() abort
  call s:assert_throws('call macro_line#encode("\xff\xfe")', 'can not be written')
endfunction

function! Test_decode_rejects_expressions() abort
  call s:assert_throws('call macro_line#decode(''"a" . execute("qa!")'')',
        \ 'not a "..." string')
  call s:assert_throws('call macro_line#decode("system(''ls'')")',
        \ 'not a "..." string')
endfunction

function! Test_parse() abort
  call assert_equal({}, macro_line#parse('no macro here'))
  let l:m = macro_line#parse('# swap: `let @q = "a\"b"` -- run with @q')
  call assert_equal('q', l:m.register)
  call assert_equal('"a\"b"', l:m.literal)
  call assert_equal(18, l:m.start)
  call assert_equal(24, l:m.end)
  call assert_equal('"', macro_line#parse('let @" = "x"').register)
  call assert_equal({}, macro_line#parse('let @: = "x"'))
endfunction

function! Test_put_and_load() abort
  call s:reset(['one', '  two'])
  call setreg('a', "0f D\<Esc>j", 'c')
  call cursor(2, 1)
  call assert_equal(3, macro_line#put('a', 2, 0))
  call assert_equal('  let @a = "0f D\<Esc>j"', getline(3))
  call assert_equal([3, 3], [line('.'), col('.')])
  call setreg('a', '')
  call assert_equal(['a'], macro_line#load(3, 3, ''))
  call assert_equal("0f D\<Esc>j", getreg('a'))
  call assert_equal('v', getregtype('a'))
  " Into another register.
  call assert_equal(['b'], macro_line#load(3, 3, 'b'))
  call assert_equal("0f D\<Esc>j", getreg('b'))
  " Above.
  call assert_equal(1, macro_line#put('a', 1, 1))
  call assert_equal(4, line('$'))
endfunction

function! Test_put_uppercase_saves_lowercase() abort
  call s:reset(['x'])
  call setreg('c', 'dd')
  call macro_line#put('C', 1, 0)
  call assert_equal('let @c = "dd"', getline(2))
endfunction

function! Test_linewise_register() abort
  call s:reset(['x'])
  call setreg('l', ['yyp'], 'l')
  call macro_line#put('l', 1, 0)
  call setreg('l', '')
  call macro_line#load(2, 2, '')
  call assert_equal("yyp\n", getreg('l'))
  call assert_equal('V', getregtype('l'))
endfunction

function! Test_put_errors() abort
  call s:reset(['x'])
  call setreg('e', '')
  call assert_equal(0, macro_line#put('e', 1, 0))
  call assert_equal(0, macro_line#put('=', 1, 0))
  call assert_equal(1, line('$'))
endfunction

function! Test_load_range() abort
  call s:reset([
        \ 'Fix a heading: let @h = "I# \<Esc>j"',
        \ 'prose',
        \ '// let @w = "dw"',
        \ ])
  call assert_equal(['h', 'w'], macro_line#load(1, 3, ''))
  call assert_equal("I# \<Esc>j", getreg('h'))
  call assert_equal('dw', getreg('w'))
  call assert_equal([], macro_line#load(2, 2, ''))
endfunction

function! Test_update() abort
  call s:reset(['/* let @q = "old" */ trailing'])
  call setreg('q', "new\<CR>", 'c')
  call assert_equal(1, macro_line#update(1, ''))
  call assert_equal('/* let @q = "new\<CR>" */ trailing', getline(1))
  " Loading a macro that ends in <CR> keeps it characterwise.
  call setreg('q', '')
  call macro_line#load(1, 1, '')
  call assert_equal(["new\r", 'v'], [getreg('q'), getregtype('q')])
  call setreg('z', 'zz')
  call macro_line#update(1, 'z')
  call assert_equal('/* let @q = "zz" */ trailing', getline(1))
  call s:reset(['nothing'])
  call assert_equal(0, macro_line#update(1, ''))
endfunction

function! Test_templates() abort
  call setreg('q', 'dd')
  call s:reset(['x'], 'python')
  setlocal commentstring=#%s
  call macro_line#put('q', 1, 0)
  call assert_equal('# let @q = "dd"', getline(2))

  call s:reset(['x'], 'c')
  setlocal commentstring=/*%s*/
  call macro_line#put('q', 1, 0)
  call assert_equal('/* let @q = "dd" */', getline(2))

  call s:reset(['x'], 'markdown')
  call macro_line#put('q', 1, 0)
  call assert_equal('`let @q = "dd"`', getline(2))
  call setreg('q', 'f`x')
  call macro_line#put('q', 1, 0)
  call assert_equal('`` let @q = "f`x" ``', getline(2))

  call setreg('q', 'dd')
  call s:reset(['x'], 'markdown.pandoc')
  call macro_line#put('q', 1, 0)
  call assert_equal('`let @q = "dd"`', getline(2))

  call s:reset(['x'], 'text')
  call macro_line#put('q', 1, 0)
  call assert_equal('let @q = "dd"', getline(2))

  call s:reset(['x'], 'python')
  let b:macro_line_template = '%s  # macro'
  call macro_line#put('q', 1, 0)
  call assert_equal('let @q = "dd"  # macro', getline(2))

  let g:macro_line_templates = {'python': '## %s'}
  call s:reset(['x'], 'python')
  call macro_line#put('q', 1, 0)
  call assert_equal('## let @q = "dd"', getline(2))
  unlet g:macro_line_templates
endfunction

function! Test_default_register() abort
  let g:macro_line_register = 'm'
  call assert_equal('m', macro_line#default_register())
  unlet g:macro_line_register
  if exists('*reg_recorded')
    if reg_recorded() ==# ''
      call assert_equal('q', macro_line#default_register())
    endif
  else
    " Vim: there is no reg_recorded().
    call assert_equal('q', macro_line#default_register())
  endif
endfunction

function! Test_commands() abort
  call s:reset(['x', 'y'])
  call setreg('a', 'AA')
  call setreg('q', 'QQ')
  MacroPut a
  call assert_equal('let @a = "AA"', getline(2))
  1MacroPut! q
  call assert_equal('let @q = "QQ"', getline(1))
  call setreg('a', '')
  call setreg('q', '')
  %MacroLoad
  call assert_equal(['AA', 'QQ'], [getreg('a'), getreg('q')])
  1MacroLoad b
  call assert_equal('QQ', getreg('b'))
  call setreg('q', 'new')
  1MacroUpdate
  call assert_equal('let @q = "new"', getline(1))
endfunction

function! Test_mappings() abort
  call assert_equal('<Plug>(macro-line-put)', maparg('\mp', 'n'))
  call assert_equal('<Plug>(macro-line-load)', maparg('\ml', 'x'))
  call s:reset(['x'])
  call setreg('a', 'AA')
  execute "normal \"a\\mp"
  call assert_equal('let @a = "AA"', getline(2))
  call setreg('c', '')
  execute "normal \"c\\ml"
  call assert_equal('AA', getreg('c'))
  call setreg('a', 'BB')
  execute "normal \\mu"
  call assert_equal('let @a = "BB"', getline(2))
endfunction

" Runner.
let s:failed = 0
let s:tests = sort(filter(split(execute('function /^Test_'), "\n"),
      \ 'v:val =~# ''^function Test_'''))
let s:tests = map(s:tests, 'matchstr(v:val, ''Test_\w\+'')')
for s:test in s:tests
  let v:errors = []
  try
    call call(s:test, [])
  catch
    call add(v:errors, s:test . ': ' . v:exception . ' @ ' . v:throwpoint)
  endtry
  if empty(v:errors)
    call writefile(['ok   ' . s:test], '/dev/stdout', 'a')
  else
    let s:failed += 1
    call writefile(['FAIL ' . s:test] + map(v:errors, '"     " . v:val'),
          \ '/dev/stdout', 'a')
  endif
endfor
call writefile([printf('%d tests, %d failed', len(s:tests), s:failed)],
      \ '/dev/stdout', 'a')
" Exit status reports the result.
execute s:failed ? "cquit!" : "qall!"
