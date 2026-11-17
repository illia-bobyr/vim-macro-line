# vim-macro-line

Keep Vim macros inside the files they work on, as readable lines, and load them
back into registers.

Some macros only make sense for one file, or a group of files: reformat this
table, renumber those headings.  They are worth keeping beyond the current
session, together with a note on how to use them.  Saving a register into the
file directly does not work well, as macros are full of raw control characters
and terminal key codes.  This plugin writes the register in `<>` key notation
instead (using `keytrans()`), as a line you can read, edit and source:

```markdown
Turn a "Name: value" line into a table row, cursor on the line:
`let @t = "I| \<Esc>f:r|A |\<Esc>j"`
```

`:MacroLoad` on that line puts the macro back into register `t`.

## Installation

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'illia-bobyr/vim-macro-line'
```

With Vim's native packages:

```sh
git clone https://github.com/illia-bobyr/vim-macro-line \
  ~/.vim/pack/plugins/start/vim-macro-line
vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/vim-macro-line/doc' -c q
```

Needs `keytrans()`: Vim 9.0 or Neovim 0.8.

## Usage

Default bindings, in Normal mode.  Prefix with `"x` to use register `x`:

- `<Leader>mp` -- put a macro line below the cursor.  Without a register: the
  register you recorded into last, else `q`.
- `<Leader>mP` -- the same, above the cursor.
- `<Leader>ml` -- load the macro on the cursor line into its register (or into
  `x`, with `"x`).  `[count]` lines, or the selected lines in Visual mode.
- `<Leader>mu` -- update the macro on the cursor line from its register, after
  you recorded it again.

A binding is only created when its key is not already mapped to something else,
and when you have not mapped the plugin's `<Plug>` mapping yourself.

The same from the command line:

```vim
:MacroPut q          " put register q below the cursor line
:MacroPut! q         " ... above it
:MacroLoad           " load the macro on the cursor line
:MacroLoad a         " ... into register a instead
:%MacroLoad          " load every macro in the file
:MacroUpdate         " rewrite the macro on the cursor line from its register
```

The macro can sit anywhere on a line, so it can live in a comment, in a list
item, or next to its explanation.  A new line is wrapped to fit the file:
a comment (`'commentstring'`) in code, inline code in Markdown, nothing in plain
text.

Loading never runs anything from the file: only the `"..."` string is read, as
a string.

## Configuration

```vim
" Use other keys.  An empty string skips that binding.
let g:macro_line_put_map = '<Leader>qp'
let g:macro_line_put_above_map = '<Leader>qP'
let g:macro_line_load_map = '<Leader>ql'
let g:macro_line_update_map = ''

" Or skip all default bindings and map the <Plug> mappings yourself.
let g:macro_line_no_mappings = 1
nmap <Leader>qp <Plug>(macro-line-put)
nmap <Leader>qP <Plug>(macro-line-put-above)
nmap <Leader>ql <Plug>(macro-line-load)
xmap <Leader>ql <Plug>(macro-line-load)
nmap <Leader>qu <Plug>(macro-line-update)

let g:macro_line_register = 'q'   " always save q when no register is given
let g:macro_line_quiet = 1        " don't echo what was loaded or updated

" How a new line is wrapped, per filetype.  "%s" is the `let` line.
let g:macro_line_templates = {'markdown': '%s', 'python': '## %s'}
```

To load a file's macros whenever you open it:

```vim
autocmd BufReadPost ~/notes/*.md silent! %MacroLoad
```

See `:help macro-line` for the full reference.

## License

MIT, see [LICENSE](LICENSE).
