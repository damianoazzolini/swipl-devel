/*  pce.pl,v 1.2 1992/09/03 08:48:29 jan Exp

    Part of XPCE
    Designed and implemented by Anjo Anjewierden and Jan Wielemaker
    E-mail: jan@swi.psy.uva.nl

    Copyright (C) 1992 University of Amsterdam. All rights reserved.
*/

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Module PCE.  This module defines the core   of  XPCE.  It is designed in
such a way that it  may  be   compiled  using  the SWI-Prolog qcompile/1
compiler, which makes XPCE an autoloadable module of SWI-Prolog.

Various things are Prolog-implementation specific in this module and
therefore each Prolog system will require a different version of this
module.

This module only defines some  paths,  some   things  to  make  the .qlf
compiler work on it and  finally  it   just  loads  the XPCE modules and
reexports the content of these files.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(pce,
	  [ new/2, free/1		% pce_principal predicates

	  , send/2, send/3, send/4, send/5, send/6, send/7
	  , send/8, send/9, send/10, send/11, send/12

	  , get/3, get/4, get/5, get/6, get/7, get/8
	  , get/9, get/10, get/11, get/12, get/13

	  , object/1, object/2

	  , pce_global/2		% pce_global
	  , pce_autoload/2		% pce_autoload
	  , pce_autoload_all/0

	  , pce_predicate_reference/2
	  , pce_term_expansion/2
	  , pce_compiling/1
	  , pce_begin_recording/1
	  , pce_end_recording/0

	  , pce_register_class/1
	  , pce_extended_class/1
	  , pce_prolog_class/1
	  , pce_prolog_class/2
	  , pce_bind_send_method/8
	  , pce_bind_get_method/9
	  , pce_send_method_message/2
	  , pce_get_method_message/2

	  , pce_catch_error/2		% pce_error

	  , strip_module/3		% pce_pl (module pce_host)
	  , require/1
	  , auto_call/1
	  , (meta_predicate)/1
	  , 'pceloadc++'/1
	  , 'pceloadc++'/2
	  , 'pceloadcxx'/1
	  , 'pceloadcxx'/2
	  , '$call_atom'/1
	  , pce_error/1
	  , pce_warn/1
	  , pce_info/1
	  , pce_welcome/0
	  ]).


user:term_expansion((:- require(_)), []).

		/********************************
		*      LOAD COMMON PLATFORM	*
		********************************/

:- prolog_load_context(directory, Dir),
   concat(Dir, '/../boot', RawBootDir),
   absolute_file_name(RawBootDir, BootDir),
   assert(user:file_search_path(pce_boot, BootDir)).

:- [user:pce_boot(pce_expand)].

:- [ pce_boot(pce_pl),
     pce_boot(pce_principal),
     pce_boot(pce_error),
     pce_boot(pce_operator),
     pce_boot(pce_global),
     pce_boot(pce_expansion),
     pce_boot(pce_realise),
     pce_boot(pce_autoload),
     pce_boot(pce_editor)
   ].

:- retractall(user:file_search_path(pce_boot, _)).

set_version :-
	feature(version, PlVersion),
	send(@pce, catch_error_signals, @on),
	concat('SWI-Prolog version ', PlVersion, PlId),
	send(@prolog, system, PlId).

:- initialization set_version.
   
get_pce_version :-
	(   feature(xpce_version, _)
	->  true
	;   get(@pce, version, name, Version),
	    set_feature(xpce_version, Version)
	).

:- initialization get_pce_version.

		/********************************
		*           SET PCE HOME	*
		********************************/

set_xpce_home :-
	absolute_file_name(pce('Pce'), [exists], ResourceFile), !,
	file_directory_name(ResourceFile, PceHome),
	send(@pce, home, PceHome).
set_xpce_home :-
	prolog_load_context(directory, LibDir),
	file_directory_name(LibDir, PrologDir),
	file_directory_name(PrologDir, PceHome),
	absolute_file_name(PceHome, CanonicalHome),
	send(@pce, home, CanonicalHome).

:- initialization set_xpce_home.


		 /*******************************
		 *	     CONSOLE		*
		 *******************************/

%:- send(@pce, console_label, 'XPCE/SWI-Prolog').


		/********************************
		*       PROLOG LIBRARIES	*
		********************************/

:- multifile
	user:file_search_path/2.

user:file_search_path(demo, pce('prolog/demo')).
user:file_search_path(contrib, pce('prolog/contrib')).


		/********************************
		*            BANNER		*
		********************************/

pce_welcome :-
	send(@pce, banner),
	(   get(@pce, is_runtime_system, @(off))
	->  format('~nFor HELP on prolog, please type help. or apropos(topic).~n'),
	    format('         on xpce, please type manpce.~n~n')
	;   format('~n', [])
	).


:- flag('$banner_goal', _, pce_welcome).

		/********************************
		*        LOCK LOADED FILES	*
		********************************/

:- '$make_system_source_files'.
:- '$autoload':clear_library_index.
