" LaTeX Box completion

" <SID> Wrap {{{
function! s:SIDWrap(func)
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze.*$') . a:func
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
		elseif line[0:pos-1] =~ '\\\(eq\)\?ref\_\s*{$'
			let s:completion_type = 'ref'
		elseif line[0:pos-1] =~ '\\cite\(p\|t\)\?\_\s*{$'
			let s:completion_type = 'bib'
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
			return s:CompleteLabels(a:base)
		elseif s:completion_type == 'bib'
			" suggest BibTeX entries
			return LatexBox_BibComplete(a:base)
		endif
		return suggestions
	endif
endfunction
" }}}


" BibTeX search {{{

" find the \bibliography{...} command
function! s:FindBibData()
    "FIXME: use main tex file
	for line in readfile(LatexBox_GetMainTexFile())
    	let bibdata = matchstr(line, '\\bibliography\_\s*{\zs[^}]*\ze}')
		if !empty(bibdata)
			return bibdata
		endif
	endfor
	return ''
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
    silent execute '! cd ' shellescape(LatexBox_GetTexRoot()) . ' ; bibtex -terse ' . fnamemodify(auxfile, ':t')

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
		let regexp = substitute(a:regexp, '\s\+', '.*', 'g')
	else
		let regexp = a:regexp
	endif

    let res = []
    for m in LatexBox_BibSearch(regexp)
        let w = {'word': m['key'],
					\ 'abbr': '[' . m['type'] . '] ' . m['author'] . ' (' . m['year'] . ')',
					\ 'menu': m['title']}
		if g:LatexBox_completion_close_braces
			" add trailing '}'
			let w.word = w.word . '}'
		endif
        call add(res, w)
    endfor
    return res
endfunction
" }}}


" Complete Labels {{{
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
		let matches = matchlist(line, '^\\newlabel{\(' . a:regex . '[^}]*\)}{{\([^}]*\)}{\([^}]*\)}}')
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

		let included_auxfile = matchstr(line, '^\\@input{\zs[^}]*\ze}')
		if included_auxfile != ''
			let included_auxfile = prefix . '/' . included_auxfile
			call extend(suggestions, s:CompleteLabels(a:regex, included_auxfile))
		endif
	endfor

	return suggestions

endfunction
" }}}



" Find tex label by number {{{
function! LatexBox_FindLabelByNumber(regex, number)

	let auxfiles = [LatexBox_GetAuxFile()]

	while !empty(auxfiles)

		let auxfile = auxfiles[0]

		" search for the target equation number
		for line in readfile(auxfile)
			let label = matchstr(line, '^\\newlabel{\zs' . a:regex . '[^}]*\ze}{{' . a:number . '}')
			if label != ''
				return label
			endif
		endfor

		call extend(auxfiles, LatexBox_GetAuxIncludedFiles(auxfile))
		call remove(auxfiles, 0)

	endwhile

	" no match found; return the empty string
	return ''

endfunction
" }}}

" Find tex label by number with prompt {{{
function! LatexBox_FindLabelByNumberPrompt()

	let regex = input('label prefix: ', '', 'customlist,' . s:SIDWrap('GetLabelTypes'))
	let number = input('label number: ')
	return LatexBox_FindLabelByNumber(regex, number)
endfunction

function! s:GetLabelTypes(lead, cmdline, pos)
	let l:label_types = ['eq:', 'fig:', 'tab:']
	let suggestions = []
	for l:w in l:label_types
		if l:w =~ '^' . a:lead
			call add(suggestions, l:w)
		endif
	endfor
	return suggestions
endfunction
" }}}

" Templates {{{

function! s:GetTemplateList(lead, cmdline, pos)
	let suggestions = []
	for env in keys(g:LatexBox_templates)
		if env =~ '^' . a:lead
			call add(suggestions, env)
		endif
	endfor
	return suggestions
endfunction


function! LatexBox_Template(env, close)
	let envdata = get(g:LatexBox_templates, a:env, {})

	let text = '\begin{' . a:env . '}'

	if has_key(envdata, 'options')
		let text .= envdata.options
	endif
	if a:close
		let text .= "\<End>\n" . '\end{' . a:env . '}' . "\<Up>\<End>"
	endif
	if has_key(envdata, 'template')
		let text .= "\n" . envdata.template
	endif
	if has_key(envdata, 'label')
		let text .= "\n" . '\label{' . envdata.label . '}' . "\<Left>"
	endif

	return text
endfunction

function! LatexBox_TemplatePrompt(close)
	let env = input('Environment: ', '', 'customlist,' . s:SIDWrap('GetEnvList'))
	return LatexBox_Template(env, a:close)
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

" Close Last Environment {{{
function! LatexBox_CloseLastEnv()
	let env = s:GetLastUnclosedEnv()
	if env != ''
		return '\end{' . env . '}'
	else
		return ''
	endif
endfunction
" }}}

" Wrap Selection {{{
function! LatexBox_WrapSelection(wrapper)
	normal `>a}
	exec 'normal `<i\'.a:wrapper.'{'
endfunction
" }}}


" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
