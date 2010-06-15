" LaTeX Box common functions

" Settings {{{

" Compilation {{{

" g:vim_program {{{
if !exists('g:vim_program')

	" attempt autodetection of vim executable
	let g:vim_program = ''
	let tmpfile = tempname()
	silent execute '!ps -o command= -p $PPID > ' . tmpfile
	for line in readfile(tmpfile)
		let line = matchstr(line, '^\S\+\>')
		if !empty(line) && executable(line)
			let g:vim_program = line . ' -g'
			break
		endif
	endfor
	call delete(tmpfile)

	if empty(g:vim_program)
		if has('gui_macvim')
			let g:vim_program = '/Applications/MacVim.app/Contents/MacOS/Vim -g'
		else
			let g:vim_program = v:progname
		endif
	endif
endif
" }}}

if !exists('g:LatexBox_latexmk_options')
	let g:LatexBox_latexmk_options = ''
endif
if !exists('g:LatexBox_output_type')
	let g:LatexBox_output_type = 'pdf'
endif
if !exists('g:LatexBox_viewer')
	let g:LatexBox_viewer = 'xdg-open'
endif
" }}}

" Completion {{{
if !exists('g:LatexBox_completion_close_braces')
	let g:LatexBox_completion_close_braces = 1
endif
if !exists('g:LatexBox_bibtex_wild_spaces')
	let g:LatexBox_bibtex_wild_spaces = 1
endif

if !exists('g:LatexBox_cite_pattern')
	let g:LatexBox_cite_pattern = '\\cite\(p\|t\)\?\*\?\_\s*{'
endif
if !exists('g:LatexBox_ref_pattern')
	let g:LatexBox_ref_pattern = '\\v\?\(eq\|page\)\?ref\*\?\_\s*{'
endif

if !exists('g:LatexBox_completion_environments')
	let g:LatexBox_completion_environments = [
		\ {'word': 'itemize',		'menu': 'bullet list' },
		\ {'word': 'enumerate',		'menu': 'numbered list' },
		\ {'word': 'description',	'menu': 'description' },
		\ {'word': 'center',		'menu': 'centered text' },
		\ {'word': 'figure',		'menu': 'floating figure' },
		\ {'word': 'table',			'menu': 'floating table' },
		\ {'word': 'equation',		'menu': 'equation (numbered)' },
		\ {'word': 'align',			'menu': 'aligned equations (numbered)' },
		\ {'word': 'align*',		'menu': 'aligned equations' },
		\ {'word': 'document' },
		\ {'word': 'abstract' },
		\ ]
endif

if !exists('g:LatexBox_completion_commands')
	let g:LatexBox_completion_commands = [
		\ {'word': '\begin{' },
		\ {'word': '\end{' },
		\ {'word': '\item' },
		\ {'word': '\label{' },
		\ {'word': '\ref{' },
		\ {'word': '\eqref{eq:' },
		\ {'word': '\cite{' },
		\ {'word': '\nonumber' },
		\ {'word': '\bibliography' },
		\ {'word': '\bibliographystyle' },
		\ ]
endif
" }}}

" Templates {{{
if !exists('g:LatexBox_templates')
	let g:LatexBox_templates = {
				\ 'document':	{},
				\ 'abstract':	{},
				\ 'itemize':	{'template': "\<Tab>\\item "},
				\ 'enumerate':	{'template': "\<Tab>\\item "},
				\ 'figure':	 	{'label': 'fig:', 'options': '[htb]'},
				\ 'table':		{'label': 'tab:', 'options': '[htb]'},
				\ 'tabular':	{'options': '[cc]'},
				\ 'center':	 	{},
				\ 'equation':	{'label': 'eq:'},
				\ 'align':		{'label': 'eq:'},
				\ 'gather':		{'label': 'eq:'},
				\ }
endif
" }}}

" }}}

" Filename utilities {{{
"
function! LatexBox_GetMainTexFile()

	" 1. check for the b:main_tex_file variable
	if exists('b:main_tex_file') && glob(b:main_tex_file, 1) != ''
		return b:main_tex_file
	endif

	" 2. scan current file for "\begin{document}"
	if &filetype == 'tex' && search('\\begin\_\s*{document}', 'nw') != 0
		return expand('%:p')
	endif

	" 3. prompt for file with completion
	let b:main_tex_file = s:PromptForMainFile()
	return b:main_tex_file
endfunction

function! s:PromptForMainFile()
	let saved_dir = getcwd()
	execute 'cd ' . expand('%:p:h')
	let l:file = ''
	while glob(l:file, 1) == ''
		let l:file = input('main LaTeX file: ', '', 'file')
		if l:file !~ '\.tex$'
			let l:file .= '.tex'
		endif
	endwhile
	execute 'cd ' . saved_dir
	return l:file
endfunction

" Return the directory of the main tex file
function! LatexBox_GetTexRoot()
	return fnamemodify(LatexBox_GetMainTexFile(), ':h')
endfunction

"!function! LatexBox_GetTexFile()
"!	if &filetype != 'tex'
"!		echomsg 'not a tex file'
"!		return ''
"!	endif
"!	return expand("%:p")
"!endfunction

function! LatexBox_GetTexBasename(with_dir)
	if a:with_dir
		return fnamemodify(LatexBox_GetMainTexFile(), ':r')
	else
		return fnamemodify(LatexBox_GetMainTexFile(), ':t:r')
	endif
endfunction

function! LatexBox_GetAuxFile()
	return LatexBox_GetTexBasename(1) . '.aux'
endfunction

function! LatexBox_GetLogFile()
	return LatexBox_GetTexBasename(1) . '.log'
endfunction

function! LatexBox_GetOutputFile()
	return LatexBox_GetTexBasename(1) . '.' . g:LatexBox_output_type
endfunction
" }}}

" FIXME: remove this
"!" GetAuxIncludedFiles {{{
"!function! LatexBox_GetAuxIncludedFiles(auxfile)
"!
"!	let files = []
"!	let prefix = fnamemodify(a:auxfile, ':p:h')
"!
"!	for line in readfile(a:auxfile)
"!		let newaux = matchstr(line, '^\\@input{\zs[^}]*\ze}')
"!		if newaux != ''
"!			call add(files, prefix . '/' . newaux)
"!		endif
"!	endfor
"!
"!	return files
"!
"!endfunction

" }}}

" View {{{
function! LatexBox_View()
	let outfile = LatexBox_GetOutputFile()
	if !filereadable(outfile)
		echomsg fnamemodify(outfile, ':.') . ' is not readable'
		return
	endif
	silent execute '!' . g:LatexBox_viewer ' ' . shellescape(LatexBox_GetOutputFile()) . ' &'
endfunction

command! LatexView			call LatexBox_View()
" }}}


" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
