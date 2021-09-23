(lang dune 2.8)
(version 1.4.0)

(generate_opam_files true)

(using menhir 2.0)
(using dune_site 0.1)

(authors
  "François Bobot"
  "Jean-Christophe Filliâtre"
  "Claude Marché"
  "Guillaume Melquiond"
  "Andrei Paskevich"
)

(license "LGPL-2.1-only")

(maintainers "guillaume.melquiond@inria.fr")

(homepage "http://why3.lri.fr/")

(bug_reports "https://gitlab.inria.fr/why3/why3/issues")

(source (uri "git+https://gitlab.inria.fr/why3/why3.git"))

(documentation "http://why3.lri.fr/doc/")

(package (name why3)
         (sites (share datadir)
                (lib libdir)
                (lib plugins)
                (lib cmds))
         (depends ("menhir" (>= 20170418))
         "num")
         (depopts "zarith" "camlzip" "ocamlgraph" "re" "sexplib" ("ppx_sexp_conv" :build))
         (conflicts "why3-base" ("ocamlgraph" (< "1.8.2")))

(synopsis "Why3 environment for deductive program verification")
(description "Why3 provides a rich language for specification and programming, called WhyML, and relies on external theorem provers, both automated and interactive, to discharge verification conditions. Why3 comes with a standard library of logical theories (integer and real arithmetic, Boolean operations, sets and maps, etc.) and basic programming data structures (arrays, queues, hash tables, etc.). A user can write WhyML programs directly and get correct-by-construction OCaml programs through an automated extraction mechanism. WhyML is also used as an intermediate language for the verification of C, Java, or Ada programs.

Why3 is a complete reimplementation of the former Why platform. Among the new features are: numerous extensions to the input language, a new architecture for calling external provers, and a well-designed API, allowing to use Why3 as a software library. An important emphasis is put on modularity and genericity, giving the end user a possibility to easily reuse Why3 formalizations or to add support for a new external prover if wanted.")
(tags   ("deductive"
  "program verification"
  "formal specification"
  "automated theorem prover"
  "interactive theorem prover"))
)
(package (name why3-ide)
(tags   ("deductive"
  "program verification"
  "formal specification"
  "automated theorem prover"
  "interactive theorem prover"))

(synopsis "Why3 environment for deductive program verification")
(description "Why3 provides a rich language for specification and programming, called WhyML, and relies on external theorem provers, both automated and interactive, to discharge verification conditions. Why3 comes with a standard library of logical theories (integer and real arithmetic, Boolean operations, sets and maps, etc.) and basic programming data structures (arrays, queues, hash tables, etc.). A user can write WhyML programs directly and get correct-by-construction OCaml programs through an automated extraction mechanism. WhyML is also used as an intermediate language for the verification of C, Java, or Ada programs.

Why3 is a complete reimplementation of the former Why platform. Among the new features are: numerous extensions to the input language, a new architecture for calling external provers, and a well-designed API, allowing to use Why3 as a software library. An important emphasis is put on modularity and genericity, giving the end user a possibility to easily reuse Why3 formalizations or to add support for a new external prover if wanted.")
)
(package (name why3-coq)
(tags   ("deductive"
  "program verification"
  "formal specification"
  "automated theorem prover"
  "interactive theorem prover"))

(synopsis "Why3 environment for deductive program verification")
(description "Why3 provides a rich language for specification and programming, called WhyML, and relies on external theorem provers, both automated and interactive, to discharge verification conditions. Why3 comes with a standard library of logical theories (integer and real arithmetic, Boolean operations, sets and maps, etc.) and basic programming data structures (arrays, queues, hash tables, etc.). A user can write WhyML programs directly and get correct-by-construction OCaml programs through an automated extraction mechanism. WhyML is also used as an intermediate language for the verification of C, Java, or Ada programs.

Why3 is a complete reimplementation of the former Why platform. Among the new features are: numerous extensions to the input language, a new architecture for calling external provers, and a well-designed API, allowing to use Why3 as a software library. An important emphasis is put on modularity and genericity, giving the end user a possibility to easily reuse Why3 formalizations or to add support for a new external prover if wanted.")
)
(package (name why3-isabelle)
(tags   ("deductive"
  "program verification"
  "formal specification"
  "automated theorem prover"
  "interactive theorem prover"))
(synopsis "Why3 environment for deductive program verification")
(description "Why3 provides a rich language for specification and programming, called WhyML, and relies on external theorem provers, both automated and interactive, to discharge verification conditions. Why3 comes with a standard library of logical theories (integer and real arithmetic, Boolean operations, sets and maps, etc.) and basic programming data structures (arrays, queues, hash tables, etc.). A user can write WhyML programs directly and get correct-by-construction OCaml programs through an automated extraction mechanism. WhyML is also used as an intermediate language for the verification of C, Java, or Ada programs.

Why3 is a complete reimplementation of the former Why platform. Among the new features are: numerous extensions to the input language, a new architecture for calling external provers, and a well-designed API, allowing to use Why3 as a software library. An important emphasis is put on modularity and genericity, giving the end user a possibility to easily reuse Why3 formalizations or to add support for a new external prover if wanted.")
)
