" Qt.vim
" Author:  Dieter Hartmann <dihar@web.de>
" Version: 1.0
" License: GPL
"
" GVIM Version:  6.0+
" 
" Description: Plugin for calling the uic / qmake 
"
" Usage: Put your designer generated .ui into a clean directory. Load your .ui 
"        File into your gvim.
"        1.) use the Menu - Plugin.QT.UIC impl to create the classname.cpp
"        and the classname.h files.
"        or
"        2.) use the Menu - Plugin.QT.UIC subImpl to create a subdir
"        s:basedir, create the .cpp, .h file and moves it to the s:basedir.
"        Then create the classImpl.cpp and classImpl.h ( call uic with -subimpl
"        and -subdecl), the .pro file qmake and last the Makefile.
"
" Installation:
" Simply drop this file into your plugin directory.
"
" Changelog:
" 2003-04-02 v1.0
" 	Initial release
"

"==============================================================================
" Avoid multiple sourcing
"==============================================================================
if exists( "loaded_qt" )
  finish
endif
let loaded_qt = 1


"==============================================================================
" general settings - please change to your paths 
"==============================================================================
let s:qtdir           = "/usr/local/qt"       " where your $QTDIR points to
let s:uic             = s:qtdir ."/bin/uic"
let s:qmake           = s:qtdir ."/bin/qmake"
let s:qttype          = "thread"              " qt compiled with threads
"let s:qttype          = "qt"                 " or compiled without threads
let s:basedir         = "BASE"


nmenu &Plugin.&QT.UIC\ Impl                     :call <SID>Qt_UicCall()<CR>
imenu &Plugin.&QT.UIC\ Impl                     :<Esc>call <SID>Qt_UicCall()<CR>
nmenu &Plugin.&QT.UIC\ subImpl                  :call <SID>Qt_UicSubCall()<CR>
imenu &Plugin.&QT.UIC\ subImpl                  :<Esc>call <SID>Qt_UicSubCall()<CR>



"==============================================================================
" Qt : UIC - Aufrufe
"==============================================================================
fun! s:Qt_UicCall()

  if s:qtdir == "" || s:basedir == ""
    echo ("s:qtdir oder s:basedir nicht gesetzt")
    return
  endif

  let l:clname = s:GetClassName()

  if l:clname != ""
    execute ":!" .s:uic ." % -o ".l:clname.".h"
    execute ":!" .s:uic ." -impl ".l:clname.".h % -o ".l:clname.".cpp"
    execute "edit ".l:clname.".h"
    execute "split | edit ".l:clname.".cpp"
  endif

endfunction
"==============================================================================
" Qt : UIC - Aufrufe
"==============================================================================
fun! s:Qt_UicSubCall()

  if s:qtdir == "" || s:basedir == ""
    echo ("s:qtdir oder s:basedir nicht gesetzt")
    return
  endif

  let l:clname = s:GetClassName()

  if l:clname != ""
    " --- create BASE-Dir
    let l:ret = system("mkdir " .s:basedir)
    if strlen(l:ret) == 0
      "
      " --- call the UIC 
      execute ":!" .s:uic ." % -o ".l:clname.".h"
      execute ":!" .s:uic ." -impl ".l:clname.".h % -o " .l:clname.".cpp"
      execute ":!" .s:uic ." -subdecl " .l:clname ."Impl " .l:clname .".h " " % -o " .l:clname ."Impl.h"
      execute ":!" .s:uic ." -subimpl " .l:clname."Impl " .l:clname ."Impl.h % -o ".l:clname."Impl.cpp"
      "
      " --- move to BASE-Dir
      let l:cmd = "mv " .expand("%") ." " .s:basedir ."/" .l:clname .".ui" 
      call system(l:cmd) 
      let l:cmd = "mv " .l:clname .".h " .l:clname .".cpp " .s:basedir
      call system(l:cmd) 
      "
      " --- Was haben wir den da ?!
      execute "edit " .l:clname ."Impl.cpp"
      execute "split | edit " .l:clname ."Impl.h"
      execute "split | edit main.cpp"
      call s:CreateMainFile( l:clname )
      execute "write"

      execute "split | edit my.pro"
      call s:CreateProFile( l:clname )
      execute "write"

      " --- qmake
      let l:ret = confirm("Should I run qmake now ?", "&Yes\n&No", 1, "Question")
      if l:ret == 1
        execute s:qmake ." my.pro "
        " --- make
        let l:ret = confirm("Should I run make now ?", "&Yes\n&No", 1, "Question")
        if l:ret == 1
          execute "make"
        endif
      endif
    endif
  endif

endfunction

"==============================================================================
" --- Helperfunctions
"==============================================================================

"==============================================================================
" Reads the class name from the .ui File and asks for changing that.
" Returns the class name.
"==============================================================================
function s:GetClassName()

  let l:counter = 1

  while l:counter < line("$") 
    "echo l:counter
    let l:ret = matchstr( getline(l:counter) , "<class>.*</class>")
    if strlen(l:ret) != 0
      let l:starts = matchend( getline(l:counter) , ">")
      let l:ends = match( getline(l:counter) , "</")
      let l:oldcl = strpart( l:ret, l:starts, l:ends-l:starts)
      break
    endif
    let l:counter = l:counter + 1
  endwhile

  " --- should I change the class name ?
  "
  let l:clname = inputdialog("Do you want to change that class name ?", l:oldcl)
  if l:clname != "" && l:clname != l:oldcl
    execute l:counter ." s/" .l:oldcl ."/" .l:clname ."/"
    execute ("write")
  endif

  return l:clname

endfun


"==============================================================================
" creates the main.cpp - like Qt does ist.
"==============================================================================
function s:CreateMainFile( clname)

  call append("$", "#include <qapplication.h>")
  call append("$", "#include \"" .a:clname ."Impl.h\"")
  call append("$", "")
  call append("$", "int main( int argc, char ** argv )")
  call append("$", "{")
  call append("$", "  QApplication a( argc, argv );")
  call append("$", "  " .a:clname ."Impl w;")
  call append("$", "  w.show();")
  call append("$", "  a.connect( &a, SIGNAL( lastWindowClosed() ), &a, SLOT( quit() ) );")
  call append("$", "  return a.exec();")
  call append("$", "}")

endfun

"==============================================================================
" creates the my.pro - like Qt does ist.
"==============================================================================
function s:CreateProFile( clname)

  let l:target = inputdialog("What should by the name of the new program ?", a:clname )
  if l:target == ""
    " --- no program name ?? -- What's that ?
    return
  endif

  call append("$",  "TEMPLATE = app")
  call append("$", "CONFIG	+= " .s:qttype ." warn_on release")
  call append("$", "")
  call append("$", "SOURCES	+= main.cpp")
  call append("$", "FORMS	 = ./BASE/" .a:clname .".ui")
  call append("$", "SOURCES	+= " .a:clname ."Impl.cpp")
  call append("$", "HEADERS	+= " .a:clname ."Impl.h")
  call append("$", "")
  call append("$", "LANGUAGE = C++")
  call append("$", "unix {")
  call append("$", "       TARGET      = " .l:target ."")
  call append("$", "       UI_DIR      = .ui")
  call append("$", "       MOC_DIR     = .moc")
  call append("$", "       OBJECTS_DIR = .obj")
  call append("$", "}")

endfun
