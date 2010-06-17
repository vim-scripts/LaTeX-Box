" LaTeX Box completion

" <SID> Wrap {{{
function! s:GetSID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze.*$')
endfunction
let s:SID = s:GetSID()
function! s:SIDWrap(func)
	return s:SID . a:func
endfunction
" }}}


" Omni Completion {{{

let s:completion_type = ''

function! LatexBox_Complete(findstart, base)
	if a:findstart
		" return the starting position of the word
		let line = getline('.')
		let pos = col('.') - 1
		while pos > 0 && line[pos - 1] !~ '\\\|{'
			let pos -= 1
		endwhile

		if line[0:pos-1] =~ '\\begin\_\s*{$'
			let s:completion_type = 'begin'
		elseif line[0:pos-1] =~ '\\end\_\s*{$'
			let s:completion_type = 'end'
		elseif line[0:pos-1] =~ g:LatexBox_ref_pattern . '$'
			let s:completion_type = 'ref'
		elseif line[0:pos-1] =~ g:LatexBox_cite_pattern . '$'
			let s:completion_type = 'bib'
			" check for multiple citations
			let pos = col('.') - 1
			while pos > 0 && line[pos - 1] !~ '{\|,'
				let pos -= 1
			endwhile
		else
			let s:completion_type = 'command'
			if line[pos-1] == '\'
				let pos -= 1
			endif
		endif
		return pos
	else
		" return suggestions in an array
		let suggestions = []

		if s:completion_type == 'begin'
			" suggest known environments
			for entry in g:LatexBox_completion_environments
				if entry.word =~ '^' . escape(a:base, '\')
					if g:LatexBox_completion_close_braces
						" add trailing '}'
						let entry = copy(entry)
						let entry.abbr = entry.word
						let entry.word = entry.word . '}'
					endif
					call add(suggestions, entry)
				endif
			endfor
		elseif s:completion_type == 'end'
			" suggest known environments
			let env = s:GetLastUnclosedEnv()
			if env != ''
				if g:LatexBox_completion_close_braces
					call add(suggestions, {'word': env . '}', 'abbr': env})
				else
					call add(suggestions, env)
				endif
			endif
		elseif s:completion_type == 'command'
			" suggest known commands
			for entry in g:LatexBox_completion_commands
				if entry.word =~ '^' . escape(a:base, '\')
					" do not display trailing '{'
					if entry.word =~ '{'
						let entry.abbr = entry.word[0:-2]
					endif
					call add(suggestions, entry)
				endif
			endfor
		elseif s:completion_type == 'ref'
			let suggestions = s:CompleteLabels(a:base)
		elseif s:completion_type == 'bib'
			" suggest BibTeX entries
			let suggestions = LatexBox_BibComplete(a:base)
		endif
		if !has('gui_running')
			redraw!
		endif
		return suggestions
	endif
endfunction
" }}}


" BibTeX search {{{

" find the \bibliography{...} commands
" the optional argument is the file name to be searched
function! s:FindBibData(...)

	if a:0 == 0
		let file = LatexBox_GetMainTexFile()
	else
		let file = a:1
	endif

	let prefix = fnamemodify(file, ':p:h')
	let ext = fnamemodify(file, ':e')

	let bibdata_list = []

	for line in readfile(file)

		" match \bibliography{...}
		let cur_bibdata = matchstr(line, '\\bibliography\_\s*{\zs[^}]*\ze}')
		if !empty(cur_bibdata)
			call add(bibdata_list, cur_bibdata)
		endif

		" match \include{...} or \input ...
		let included_file = matchstr(line, '\\\(input\|include\)\_\s*{\zs[^}]*\ze}')
		if empty(included_file)
			let included_file = matchstr(line, '\\@\?\(input\|include\)\_\s*\zs\S\+\ze')
		endif

		if !empty(included_file)
			if !filereadable(included_file)
				let included_file .= '.' . ext
				if !filereadable(included_file)
					continue
				endif
			endif
			call add(bibdata_list, s:FindBibData(included_file))
		endif

	endfor

	let bibdata = join(bibdata_list, ',')
	return bibdata
endfunction

let s:bstfile = expand('<sfile>:p:h') . '/vimcomplete'

function! LatexBox_BibSearch(regexp)

	" find bib data
    let bibdata = s:FindBibData()
    if bibdata == ''
        echomsg 'error: no \bibliography{...} command found'
        return
    endif

    " write temporary aux file
	let tmpbase = LatexBox_GetTexRoot() . '/_LatexBox_BibComplete'
    let auxfile = tmpbase . '.aux'
    let bblfile = tmpbase . '.bbl'
    let blgfile = tmpbase . '.blg'

    call writefile(['\citation{*}', '\bibstyle{' . s:bstfile . '}', '\bibdata{' . bibdata . '}'], auxfile)

    silent execute '! cd ' shellescape(LatexBox_GetTexRoot()) .
				\ ' ; bibtex -terse ' . fnamemodify(auxfile, ':t') . ' >/dev/null'

    let res = []
    let curentry = ''
    for l:line in readfile(bblfile)
        if l:line =~ '^\s*$'

            " process current entry
			
            if empty(curentry) || curentry !~ a:regexp
				" skip entry if void or doesn't match
				let curentry = ''
                continue
            endif
            let matches = matchlist(curentry, '^{\(.*\)}{\(.*\)}{\(.*\)}{\(.*\)}{\(.*\)}.*')
            if !empty(matches) && !empty(matches[1])
                call add(res, {'key': matches[1], 'type': matches[2],
							\ 'author': matches[3], 'year': matches[4], 'title': matches[5]})
            endif
            let curentry = ''
        else
            let curentry .= l:line
        endif
    endfor

	call delete(auxfile)
	call delete(bblfile)
	call delete(blgfile)

	return res
endfunction
" }}}

" BibTeX completion {{{
function! LatexBox_BibComplete(regexp)

	" treat spaces as '.*' if needed
	if g:LatexBox_bibtex_wild_spaces
		"let regexp = substitute(a:regexp, '\s\+', '.*', 'g')
		let regexp = '.*' . substitute(a:regexp, '\s\+', '\\\&.*', 'g')
	else
		let regexp = a:regexp
	endif

    let res = []
    for m in LatexBox_BibSearch(regexp)

        let w = {'word': m['key'],
					\ 'abbr': '[' . m['type'] . '] ' . m['author'] . ' (' . m['year'] . ')',
					\ 'menu': m['title']}

		" close braces if needed
		if g:LatexBox_completion_close_braces
			let rest_of_line = strpart(getline("."), getpos(".")[2] - 1)
			if rest_of_line !~ '^\s*[,}]'
				let w.word = w.word . '}'
			endif
		endif

        call add(res, w)
    endfor
    return res
endfunction
" }}}


" Complete Labels {{{
" the optional argument is the file name to be searched
function! s:CompleteLabels(regex, ...)

	let suggestions = []

	if a:0 == 0
		let auxfile = LatexBox_GetAuxFile()
	else
		let auxfile = a:1
	endif

	let prefix = fnamemodify(auxfile, ':p:h')

	" search for the target equation number
	for line in readfile(auxfile)

		" search for matching label
		let matches = matchlist(line, '^\\newlabel{\(' . a:regex . '[^}]*\)}{{\([^}]*\)}{\([^}]*\)}.*}')

		if empty(matches)
			" also try to match label and number
			let regex_split = split(a:regex)
			let base = regex_split[0]
			let number = escape(join(regex_split[1:], ' '), '.')
			let matches = matchlist(line, '^\\newlabel{\(' . base . '[^}]*\)}{{\(' . number . '\)}{\([^}]*\)}.*}')
		endif

		if empty(matches)
			" also try to match number
			let matches = matchlist(line, '^\\newlabel{\([^}]*\)}{{\(' . escape(a:regex, '.') . '\)}{\([^}]*\)}.*}')
		endif

		if !empty(matches)

			let entry = {'word': matches[1], 'menu': '(' . matches[2] . ') [p.' . matches[3] . ']'}

			if g:LatexBox_completion_close_braces
				" add trailing '}'
				let entry = copy(entry)
				let entry.abbr = entry.word
				let entry.word = entry.word . '}'
			endif
			call add(suggestions, entry)
		endif

		" search for included files
		let included_auxfile = matchstr(line, '^\\@input{\zs[^}]*\ze}')
		if included_auxfile != ''
			let included_auxfile = prefix . '/' . included_auxfile
			call extend(suggestions, s:CompleteLabels(a:regex, included_auxfile))
		endif
	endfor

	return suggestions

endfunction
" }}}


" DEPRECATED
"!" Find TeX label by number {{{
"!function! s:LabelByNumber(regex, number, ...)
"!
"!	if a:0 == 0
"!		let auxfile = LatexBox_GetAuxFile()
"!	else
"!		let auxfile = a:1
"!	endif
"!
"!	echomsg 'label by number for ' . auxfile
"!
"!	let prefix = fnamemodify(auxfile, ':p:h')
"!
"!	" search for the target equation number
"!	for line in readfile(auxfile)
"!
"!		" search for matching label
"!		let label = matchstr(line, '^\\newlabel{\zs' . a:regex . '[^}]*\ze}{{' . a:number . '}')
"!		if label != ''
"!			return label
"!		endif
"!
"!		" search for included files
"!		let included_auxfile = matchstr(line, '^\\@input{\zs[^}]*\ze}')
"!		if included_auxfile != ''
"!			let included_auxfile = prefix . '/' . included_auxfile
"!			let ret = s:LabelByNumber(a:regex, a:number, included_auxfile)
"!			if !empty(ret)
"!				return ret
"!			endif
"!		endif
"!
"!	endfor
"!
"!	" no match found; return the empty string
"!	return ''
"!
"!endfunction
"!" }}}
" DEPRECATED
"!" Find TeX label by number with prompt {{{
"!function! s:LabelByNumberPrompt()
"!	let regex = input('label prefix: ', '', 'customlist,' . s:SIDWrap('GetLabelTypes'))
"!	let number = input('label number: ')
"!	return s:LabelByNumber(regex, number)
"!endfunction
"!
"!function! s:GetLabelTypes(lead, cmdline, pos)
"!	let l:label_types = ['eq:', 'fig:', 'tab:']
"!	let suggestions = []
"!	for l:w in l:label_types
"!		if l:w =~ '^' . a:lead
"!			call add(suggestions, l:w)
"!		endif
"!	endfor
"!	return suggestions
"!endfunction
"!" }}}
" DEPRECATED
"!" Templates {{{

"!function! s:GetTemplateList(lead, cmdline, pos)
"!	let suggestions = []
"!	for env in keys(g:LatexBox_templates)
"!		if env =~ '^' . a:lead
"!			call add(suggestions, env)
"!		endif
"!	endfor
"!	return suggestions
"!endfunction

"!function! LatexBox_Template(env, close)
"!	let envdata = get(g:LatexBox_templates, a:env, {})
"!
"!	let text = '\begin{' . a:env . '}'
"!
"!	if has_key(envdata, 'options')
"!		let text .= envdata.options
"!	endif
"!	if a:close
"!		let text .= "\<End>\n" . '\end{' . a:env . '}' . "\<Up>\<End>"
"!	endif
"!	if has_key(envdata, 'template')
"!		let text .= "\n" . envdata.template
"!	endif
"!	if has_key(envdata, 'label')
"!		let text .= "\n" . '\label{' . envdata.label . '}' . "\<Left>"
"!	endif
"!
"!	return text
"!endfunction

"!function! LatexBox_TemplatePrompt(close)
"!	let env = input('Environment: ', '', 'customlist,' . s:SIDWrap('GetTemplateList'))
"!	return LatexBox_Template(env, a:close)
"!endfunction
" }}}


" Close Last Environment {{{
function! s:CloseLastEnv()
	let env = s:GetLastUnclosedEnv()
	if env != ''
		return '\end{' . env . '}'
	else
		return ''
	endif
endfunction

function! s:GetLastUnclosedEnv()
	let begin_line = searchpair('\\begin\_\s*{[^}]*}', '', '\\end\_\s*{[^}]*}', 'bnW')
	if begin_line
		let env = matchstr(getline(begin_line), '\\begin\_\s*{\zs[^}]*\ze}')
		return env
	else
		return ''
	endif
endfunction
" }}}

" Wrap Selection {{{
function! s:WrapSelection(wrapper)
	normal `>a}
	exec 'normal `<i\' . a:wrapper . '{'
endfunction
" }}}

" Mappings {{{
imap <Plug>LatexCloseLastEnv	<C-R>=<SID>CloseLastEnv()<CR>
vmap <Plug>LatexWrapSelection	:call <SID>WrapSelection('')<CR>i
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
