/*  $Id$

    Part of SWI-Prolog RDF parser

    Author:  Jan Wielemaker
    E-mail:  jan@swi.psy.uva.nl
    WWW:     http://www.swi.psy.uva.nl/projects/SWI-Prolog/
    Copying: LGPL-2.  See the file COPYING or http://www.gnu.org

    Copyright (C) 1990-2000 SWI, University of Amsterdam. All rights reserved.
*/

:- module(rdf_triple,
	  [ rdf_triples/2,		% +Parsed, -Tripples
	    rdf_triples/3,		% +Parsed, -Tripples, +Tail
	    rdf_reset_ids/0,		% Reset gensym id's
	    rdf_reset_node_ids/0	% Reset nodeID --> Node__xxx table
	  ]).
:- use_module(library(gensym)).


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Convert the output of xml_to_rdf/3  from   library(rdf)  into  a list of
triples of the format described   below. The intermediate representation
should be regarded a proprietary representation.

	rdf(Subject, Predicate, Object).

Where `Subject' is

	# Atom
	The subject is a resource
	
	# each(URI)
	URI is the URI of an RDF Bag
	
	# prefix(Pattern)
	Pattern is the prefix of a fully qualified Subject URI

And `Predicate' is

	# rdf:Predicate
	RDF reserved predicate of this name

	# Namespace:Predicate
	Predicate inherited from another namespace

	# Predicate
	Unqualified predicate

And `Object' is

	# Atom
	URI of Object resource

	# rdf:URI
	URI section in the rdf namespace (i.e. rdf:'Bag').

	# literal(Value)
	Literal value (Either a single atom or parsed XML data)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%	rdf_triples(+Term, -Tripples[, +Tail])
%
%	Convert an object as parsed by rdf.pl into a list of rdf/3
%	triples.  The identifier of the main object created is returned
%	by rdf_triples/3.
%
%	Input is the `content' of the RDF element in the format as
%	generated by load_structure(File, Term, [dialect(xmlns)]).
%	rdf_triples/3 can process both individual descriptions as
%	well as the entire content-list of an RDF element.  The first
%	mode is suitable when using library(sgml) in `call-back' mode.

rdf_triples(RDF, Tripples) :-
	rdf_triples(RDF, Tripples, []).

rdf_triples([]) --> !,
	[].
rdf_triples([H|T]) --> !,
	rdf_triples(H),
	rdf_triples(T).
rdf_triples(Term) -->
	triples(Term, _).

%	triples(-Triples, -Id, +In, -Tail)
%
%	DGC set processing the output of xml_to_rdf/3.  In Id, the identifier
%	of the main description or container is returned.

triples(container(Type, Id, Elements), Id) --> !,
	{ container_id(Type, Id)
	},
	[ rdf(Id, rdf:type, rdf:Type)
	],
	container(Elements, 1, Id).
triples(description(description, IdAbout, BagId, Props), Subject) --> !,
	{ description_id(IdAbout, Subject)
	},
	properties(Props, BagId, Subject).
triples(description(Type, IdAbout, BagId, Props), Subject) -->
	{ description_id(IdAbout, Subject),
	  name_to_type_uri(Type, TypeURI)
	},
	properties([ rdf:type = TypeURI
		   | Props
		   ], BagId, Subject).
triples(unparsed(Data), Id) -->
	{ gensym('Error__', Id),
	  print_message(error, rdf(unparsed(Data)))
	},
	[].


name_to_type_uri(NS:Local, URI) :- !,
	atom_concat(NS, Local, URI).
name_to_type_uri(URI, URI).

		 /*******************************
		 *	    CONTAINERS		*
		 *******************************/

container([], _, _) -->
	[].
container([H0|T0], N, Id) -->
	li(H0, N, Id),
	{ NN is N + 1
	},
	container(T0, NN, Id).

li(li(Nid, V), _, Id) --> !,
	[ rdf(Id, rdf:Nid, V)
	].
li(V, N, Id) -->
	triples(V, VId), !,
	{ atom_concat('_', N, Nid)
	},
	[ rdf(Id, rdf:Nid, VId)
	].
li(V, N, Id) -->
	{ atom_concat('_', N, Nid)
	},
	[ rdf(Id, rdf:Nid, V)
	].
	
container_id(_, Id) :-
	nonvar(Id), !.
container_id(Type, Id) :-
	atom_concat(Type, '__', Base),
	gensym(Base, Id).


		 /*******************************
		 *	    DESCRIPTIONS	*
		 *******************************/

:- thread_local
	node_id/2.			% nodeID --> ID

rdf_reset_node_ids :-
	retractall(node_id(_,_)).

description_id(Id, Id) :-
	var(Id), !,
	gensym('Description__', Id).
description_id(about(Id), Id).
description_id(id(Id), Id).
description_id(each(Id), each(Id)).
description_id(prefix(Id), prefix(Id)).
description_id(node(NodeID), Id) :-
	(   node_id(NodeID, Id)
	->  true
	;   gensym('Node__', Id),
	    assert(node_id(NodeID, Id))
	).

properties(PlRDF, BagId, Subject) -->
	{ nonvar(BagId)
	}, !,
	[ rdf(BagId, rdf:type, rdf:'Bag')
	],
	properties(PlRDF, 1, Statements, [], Subject),
	fill_bag(Statements, 1, BagId).
properties(PlRDF, _BagId, Subject) -->
	properties(PlRDF, 1, [], [], Subject).


fill_bag([], _, _) -->
	[].
fill_bag([H|T], N, BagId) -->
	{ NN is N + 1,
	  atom_concat('_', N, ElemId)
	},
	[ rdf(BagId, rdf:ElemId, H)
	],
	fill_bag(T, NN, BagId).


properties([], _, Bag, Bag, _) -->
	[].
properties([H0|T0], N, Bag0, Bag, Subject) -->
	property(H0, N, NN, Bag0, Bag1, Subject),
	properties(T0, NN, Bag1, Bag, Subject).

%	property(Pred = Object, N, NN, Subject)
%	property(id(Id, Pred = Object), N, NN, Subject)
%	
%	Generate triples for {Subject, Pred, Object}. In the second
%	form, reinify the statement.  Also generates triples for Object
%	if necessary.

property(Pred0 = Object, N, NN, BagH, BagT, Subject) --> % inlined object
	triples(Object, Id), !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	statement(Subject, Pred, Id, _, BagH, BagT).
property(Pred0 = collection(Elems), N, NN, BagH, BagT, Subject) --> !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	statement(Subject, Pred, Object, _Id, BagH, BagT),
	collection(Elems, Object).
property(Pred0 = Object, N, NN, BagH, BagT, Subject) --> !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	statement(Subject, Pred, Object, _Id, BagH, BagT).
property(id(Id, Pred0 = Object), N, NN, BagH, BagT, Subject) -->
	triples(Object, ObjectId), !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	statement(Subject, Pred, ObjectId, Id, BagH, BagT).
property(id(Id, Pred0 = collection(Elems)), N, NN, BagH, BagT, Subject) --> !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	statement(Subject, Pred, Object, Id, BagH, BagT),
	collection(Elems, Object).
property(id(Id, Pred0 = Object), N, NN, BagH, BagT, Subject) -->
	{ li_pred(Pred0, Pred, N, NN)
	},
	statement(Subject, Pred, Object, Id, BagH, BagT).

%	statement(+Subject, +Pred, +Object, +Id, +BagH, -BagT)
%	
%	Add a statement to the model. If nonvar(Id), we reinify the
%	statement using the given Id.

statement(Subject, Pred, Object, Id, BagH, BagT) -->
	[ rdf(Subject, Pred, Object)
	],
	{   BagH = [Id|BagT]
	->  statement_id(Id)
	;   BagT = BagH
	},
	(   { nonvar(Id)
	    }
	->  [ rdf(Id, rdf:type, rdf:'Statement'),
	      rdf(Id, rdf:subject, Subject),
	      rdf(Id, rdf:predicate, Pred),
	      rdf(Id, rdf:object, Object)
	    ]
	;   []
	).


statement_id(Id) :-
	nonvar(Id), !.
statement_id(Id) :-
	gensym('Statement__', Id).

%	li_pred(+Pred, -Pred, +Nth, -NextNth)
%	
%	Transform rdf:li predicates into _1, _2, etc.

li_pred(rdf:li, rdf:Pred, N, NN) :- !,
	NN is N + 1,
	atom_concat('_', N, Pred).
li_pred(Pred, Pred, N, N).
	
%	collection(+Elems, -Id)
%	
%	Handle the elements of a collection and return the identifier
%	for the whole collection in Id.

collection([], rdf:nil) -->
	[].
collection([H|T], Id) -->
	triples(H, HId),
	{ gensym('List__', Id)
	},
	[ rdf(Id, rdf:type, rdf:'List'),
	  rdf(Id, rdf:first, HId),
	  rdf(Id, rdf:rest, TId)
	],
	collection(T, TId).


		 /*******************************
		 *	       UTIL		*
		 *******************************/

%	rdf_reset_ids
%
%	Utility predicate to reset the gensym counters for the various
%	generated identifiers.  This simplifies debugging and matching
%	output with the stored desired output (see rdf_test.pl).

rdf_reset_ids :-
	reset_gensym('Bag__'),
	reset_gensym('Seq__'),
	reset_gensym('Alt__'),
	reset_gensym('Description__'),
	reset_gensym('Statement__'),
	reset_gensym('List__'),
	reset_gensym('Node__').
