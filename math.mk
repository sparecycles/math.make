#------------
# math.mk
#
# Basic mathematical functions and iteration in GNUmake.
# Defines +,-,<> >
#------------

#------------
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.
#------------

# define base, any radix >= 2 is supported
base := 0 1
base += 2 3 4 5 6 7 8 9
#base += a b c d e f
$(foreach rule,$(join $(addsuffix +1,$(filter-out $(lastword $(base))-,$(base)-)),$(addprefix :=,$(wordlist 2,$(words $(base)),$(base)))),$(eval $(rule)))
$(lastword $(base))+1 := 10

# define predecessor function for digits
# there is no way around this, as these symbols have little meaning to make
# _: underflow
0-1 := _
$(foreach rule,$(join $(addsuffix -1,$(wordlist 2,$(words $(base)),$(base))),$(addprefix :=,$(filter-out $(lastword $(base))-,$(base)-))),$(eval $(rule)))

# extracts the last digit from a number, make's string handling is weak.
define digit
$(strip $(foreach digit,$(base),$(and $(filter %$(digit),$(1)),$(digit))))
endef

# extracts the first digit from a number, make's string handling is weak.
define ldigit
$(strip $(foreach digit,$(base),$(and $(filter $(digit)%,$(1)),$(digit))))
endef

# - increment -
# strategy: increment the last digit and reconcat with the rest of the string,
#           if it overflows, recursively increment the rest of the number too.
define +1.compute
  +1.d := $$(call digit,$(1))
  +1.t := $$(patsubst %$$(+1.d),%,$(1))
  +1.s := $$($$(+1.d)+1)
  ifeq ($$(+1.s),10)
    +1.result := $$(if $$(+1.t),$$(call +1,$$(+1.t))0,10)
  else
    +1.result := $$(+1.t)$$(+1.s)
  endif
endef

+1 = $(eval $(call +1.compute,$(1)))$(+1.result)

# - for -
# keep evaluating for.body and for.step with incremented $(2) each time
# because make pre-expands all variables passed in a call, the for.body must
# use $$ for variables which should be expanded in the loop.
define for.step
  ifneq ($(2),$(3))
    $(1) := $(2)
    $$(eval for.result += $(value for.body))
    $$(eval $$(call for.step,$(1),$$(call +1,$(2)),$(3)))
  endif
endef

for = $(eval for.result := )$(eval for.body = $(value 4))$(eval $(call for.step,$(value 1),$(2),$(3)))$(strip $(for.result))

# - range -
# using for, build a range of numbers for use with foreach.
range = $(call for,range.var,$(1),$(2),$$(range.var))

# generate a table of the form >.table.0 := ; >.table.1 := 1, >.table.2 := 1 2, etc...
# all the numbers from 1..n for each n upto 9, (0 is included in all of them so it's not needed).
# this table is a topological implementation of > for digits.
$(foreach x,$(call range,0,10),$(eval >.table.$(x) := $(call range,1,$(call +1,$(x)))))

# - > -
# result: + if $(1)>$(2)
# strategy:
#  base-cases: $(1) is 0 -> no, else $(2) is 0 -> yes
#  if leading digits are equal: result is based on final digit
#  else recurse on leading digits.
define >.compute
  ifeq (0,$(1))
    >.result :=
  else
    ifeq (0,$(2))
      >.result := +
    else
      >.lhs.d := $$(call digit,$(1))
      >.rhs.d := $$(call digit,$(2))
      >.lhs.t := $$(patsubst %$$(>.lhs.d),%,$(1))
      >.rhs.t := $$(patsubst %$$(>.rhs.d),%,$(2))
      ifeq ($$(>.lhs.t),$$(>.rhs.t))
        >.result := $$(if $$(filter-out $$(>.table.$$(>.rhs.d)),$$(>.table.$$(>.lhs.d))),+,)
      else
        $$(eval $$(call >.compute,$$(or $$(>.lhs.t),0),$$(or $$(>.rhs.t),0)))
      endif
    endif
  endif
endef

> = $(eval $(call >.compute,$(or $(1),0),$(or $(2),0)))$(>.result)

# - <> -
# result: +,-, or 0 based on sign of $(1) - $(2)
# strategy:
#  use ifeq and >
define <>.compute
  ifeq ($(1),$(2))
    <>.result := 0
  else
    <>.result := $$(if $$(call >,$(1),$(2)),+,-)
  endif
endef

<> = $(eval $(call <>.compute,$(1),$(2)))$(<>.result)

# - +.table -
# define a table with the sum of every pair of digits.
$(foreach x,$(call range,0,10),$(foreach y,$(call range,0,10),\
  $(eval +.table.$(x)+$(y) := $(word $(words 0 $(>.table.$(x)) $(>.table.$(y))),$(base) $(addprefix 1,$(base))))))

# - + -
# adds two numbers
# strategy: add digits using table, carry overflow into upper digits and recurse.
define +.compute
  ifeq (0,$(2))
    +.result := $(1)
  else
    +.lhs.d := $$(call digit,$(1))
    +.rhs.d := $$(call digit,$(2))
    +.lhs.t := $$(or $$(patsubst %$$(+.lhs.d),%,$(1)),0)
    +.rhs.t := $$(or $$(patsubst %$$(+.rhs.d),%,$(2)),0)

    +.sum := $$(+.table.$$(+.lhs.d)+$$(+.rhs.d))
    +.sum.d := $$(call digit,$$(+.sum))
    +.sum.t := $$(patsubst %$$(+.sum.d),%,$$(+.sum))
    ifdef +.sum.t
      +.lhs.t := $$(call +1,$$(+.lhs.t))
    endif
    $$(eval +.result := $$$$(patsubst 0%,%,$$$$(call +,$$(+.lhs.t),$$(+.rhs.t))$$(+.sum.d)))
  endif
endef

+ = $(eval $(call +.compute,$(1),$(2)))$(+.result)


# - decrement -
# strategy: decrement the last digit and reconcat with the rest of the string,
#           if it underflows, recursively decrement the rest of the number too.
define -1.compute
  -1.d := $$(call digit,$(1))
  -1.t := $$(patsubst %$$(-1.d),%,$(1))
  -1.s := $$($$(-1.d)-1)
  ifeq ($$(-1.s),_)
    -1.result := $$(if $$(-1.t),$$(patsubst 0%,%,$$(call -1,$$(-1.t)))$(lastword $(base)),)
  else
    -1.result := $$(-1.t)$$(-1.s)
  endif
endef

-1 = $(eval $(call -1.compute,$(1)))$(-1.result)

# digit subtraction table
# leading understore indicates underflow.
$(foreach x,$(call range,0,10),$(foreach y,$(call range,0,10),$(eval \
  -.table.$(x)-$(y) := $(strip $(if $(filter-out $(>.table.$(x)),$(>.table.$(y))), \
    _$(word $(words 0 $(filter-out $(>.table.$(words $(filter-out $(>.table.$(x)),$(>.table.$(y))))), 0 $(>.table.$(lastword $(base))))),$(base)),\
    $(word $(words 0 $(filter-out $(>.table.$(y)),$(>.table.$(x)))),$(base)) \
  )) \
)))

define -.compute
  -.cmp := $$(call <>,$(1),$(2))

  ifeq ("-","$$(-.cmp)")
    $$(eval $$(call -.compute.work,$(2),$(1)))
    -.result := -$$(-.result)
  else
    ifeq ("0","$$(-.cmp)")
      -.result := 0
    else
      $$(eval $$(call -.compute.work,$(1),$(2)))
    endif
  endif
endef

define -.compute.work
  ifeq ("0","$(2)")
    -.result := $(1)
  else
    -.lhs.d := $$(call digit,$(1))
    -.rhs.d := $$(call digit,$(2))
    -.lhs.t := $$(or $$(patsubst %$$(-.lhs.d),%,$(1)),0)
    -.rhs.t := $$(or $$(patsubst %$$(-.rhs.d),%,$(2)),0)

    -.diff := $$(-.table.$$(-.lhs.d)-$$(-.rhs.d))
    -.diff.d := $$(call digit,$$(-.diff))
    -.diff.t := $$(patsubst %$$(-.diff.d),%,$$(-.diff))
    ifdef -.diff.t
      -.lhs.t := $$(call -1,$$(-.lhs.t))
    endif
    $$(eval -.result := $$$$(patsubst 0%,%,$$$$(call -,$$(-.lhs.t),$$(-.rhs.t))$$(-.diff.d)))
  endif
endef

# basic subtraction
- = $(eval $(call -.compute,$(1),$(2)))$(-.result)

# fixup commands to handle +/- signs
number = $(or $(patsubst -0,0,$(patsubst +%,%,$(1))),0)

+ = $(if $(filter -%,$(2)),$(call -,$(1),$(patsubst -%,%,$(2))),$(if $(filter -%,$(1)),$(call -,$(2),$(patsubst -%,%,$(1))),$(eval $(call +.compute,$(call number,$(1)),$(call number,$(2))))$(+.result)))
- = $(if $(filter -%,$(2)),$(call +,$(1),$(patsubst -%,%,$(2))),$(if $(filter -%,$(1)),-$(call +,$(2),$(patsubst -%,%,$(1))),$(eval $(call -.compute,$(call number,$(1)),$(call number,$(2))))$(-.result)))

define for.step
  ifneq ($(2),$(3))
    $(1) := $(2)
    $$(eval for.result += $(value for.body))
    $$(eval $$(call for.step,$(1),$$(call $(4),$(2),1),$(3),$(4)))
  endif
endef

for = $(eval for.result := )$(eval for.body = $(value 4))$(eval $(call for.step,$(value 1),$(call number,$(2)),$(call number,$(3)),$(call <>,$(3),$(2))))$(strip $(for.result))

define >.compute.2 
  ifeq ($(1),$(2))
    >.result :=
  else
    ifneq ($$(filter -%,$(1)),)
      ifneq ($$(filter -%,$(2)),)
        $$(eval $$(call >.compute,$$(patsubst -%,%,$(1)),$$(patsubst -%,%,$(2))))
        >.result := $$(if $$(>.result),,+)
      else
        >.result :=
      endif
    else
      ifneq ($$(filter -%,$(2)),)
        >.result := +
      else
        $$(eval $$(call >.compute,$(1),$(2)))
      endif
    endif
  endif
endef

$(foreach lhs,$(call range,0,10),\
  $(foreach rhs,$(call range,$(lhs),10),\
    $(eval * := 0) \
    $(foreach _,$(call range,0,$(rhs)),\
      $(eval * := $(call +,$(*),$(lhs)))) \
   $(eval $(rhs)*$(lhs) := $(*)) \
   $(eval $(lhs)*$(rhs) := $(*))))

define *.compute.lhs
  *.lhs.d := $$(call ldigit,$(1))
  *.lhs.t := $$(patsubst $$(*.lhs.d)%,%,$(1))
  *.result.lhs := $$(call +,$$(*.result.lhs)0,$$($$(*.lhs.d)*$(2)))
  ifdef *.lhs.t
    $$(eval $$(call *.compute.lhs,$$(*.lhs.t),$(2)))
  endif
endef

define *.compute.rhs
  *.rhs.d := $$(call ldigit,$(2))
  *.rhs.t := $$(patsubst $$(*.rhs.d)%,%,$(2))
  *.result.lhs := $$(*.cache.$$(*.rhs.d))
  ifndef *.result.lhs
    $$(eval $$(call *.compute.lhs,$(1),$$(*.rhs.d)))
    *.cache.$(2) := $$(*.result.lhs)
  endif
  *.result := $$(call +,$$(*.result)0,$$(*.result.lhs))
  ifdef *.rhs.t
    $$(eval $$(call *.compute.rhs,$(1),$$(*.rhs.t)))
  endif
endef



+.toggle = -
-.toggle = +

define *.reconfigure
  $$(if $$(filter -%,$(1)), \
    $$(eval *.sign := $$($$(*.sign).toggle)) \
    $$(eval $$(call *.reconfigure,$$(patsubst -%,%,$(1)),$(2))), \
    $$(if $$(filter -%,$(2)), \
      $$(eval *.sign := $$($$(*.sign).toggle)) \
      $$(eval $$(call *.reconfigure,$(1),$$(patsubst -%,%,$(2)))), \
      $$(eval $$(call *.compute.rhs,$(1),$(2)))))
endef

define *.configure
  *.sign := +
  *.result :=
  $(foreach digit,$(call range,0,10),$$(eval *.cache.$(digit) :=))
  $$(eval $$(call *.reconfigure,$$(call number,$(1)),$$(call number,$(2))))
endef

* = $(eval $(call *.configure,$(1),$(2)))$(call number,$(*.sign)$(*.result))

> = $(eval $(call >.compute.2,$(call number,$(1)),$(call number,$(2))))$(>.result)
<> = $(eval $(call <>.compute,$(call number,$(1)),$(call number,$(2))))$(<>.result)
< = $(call >,$(2),$(1))
<eq = $(if $(call >,$(1),$(2)),,+)
>eq = $(if $(call <,$(1),$(2)),,+)


# karatsuba implementation
# splits a number of n digits into n/2 and (n+1)/2 digits.
split = $(eval $(call split.compute,$(1),$(2)))$(if $(split.lhs),$(split.lhs),0) $(split.rhs) $(split.scale)

define split.compute
  split.lhs :=
  split.rhs :=
  split.scale :=
  ifeq ($(2),)
    $$(eval $$(call split.step,$(1)))
  else
    $$(eval $$(call split-n.step,$(1),$(2)))
  endif
endef

define split-n.step
  split.word := $(1)
  split.digit := $$(call digit,$$(split.word))
  split.rhs := $$(split.digit)$$(split.rhs)
  split.word := $$(patsubst %$$(split.digit),%,$$(split.word))
  split.scale := $$(split.scale)0
  ifneq ($$(split.scale),$(2))
    $$(eval $$(call split-n.step,$$(split.word),$(2)))
  else
    split.lhs := $$(split.word)
  endif
endef

define split.step
  split.word := $(1)
  split.digit := $$(call digit,$$(split.word))
  split.rhs := $$(split.digit)$$(split.rhs)
  split.word := $$(patsubst %$$(split.digit),%,$$(split.word))
  split.digit := $$(call ldigit,$$(split.word))
  split.lhs := $$(split.lhs)$$(split.digit)
  split.word := $$(patsubst $$(split.digit)%,%,$$(split.word))
  split.scale := $$(split.scale)0
  ifneq ($$(split.word),)
    $$(eval $$(call split.step,$$(split.word)))
  endif
endef

# karatsuba multiplcation
define *-k.compute
  *-k.lhs.split := $$(call split,$(1))
  *-k.scale := $$(word 3,$$(*-k.lhs.split))
  *-k.rhs.split := $$(call split,$(2),$$(*-k.scale))
  *-k.lhs.hi := $$(word 1, $$(*-k.lhs.split))
  *-k.lhs.lo := $$(word 2, $$(*-k.lhs.split))
  *-k.rhs.hi := $$(word 1, $$(*-k.rhs.split))
  *-k.rhs.lo := $$(word 2, $$(*-k.rhs.split))
  $$(eval $$(call *-k.collect0,$$(*-k.scale),$$(*-k.lhs.lo),$$(*-k.lhs.hi),$$(*-k.rhs.lo),$$(*-k.rhs.hi)))
endef

define *-k.collect0
  $(call *-k.collect,$1,\
    $(call *-k,$(call +,$(2),$(3)),$$(call +,$(4),$(5))),\
    $(call *-k,$(2),$(4)),\
    $(call *-k,$(3),$(5)))
endef

define *-k.collect
  *-k.result := $$(call +, $$(call +, $(4)$(1)$(1), $$(call -,$$(call -,$(2),$(3)),$(4))$(1)),$(3))
endef

define *-k.base
  *-k.result := $$($(1)*$(2))
endef

define *-k.run
  $$(if $$(call <,$(1),10),\
    $$(eval $$(call *-k.base,$(1),$(2))),\
    $$(eval $$(call *-k.compute,$(1),$(2))))
endef

define *-k.configure
 $$(if $$(call >,$(1),$(2)), \
    $$(eval $$(call *-k.run,$(1),$(2))), \
    $$(eval $$(call *-k.run,$(2),$(1))))
endef

# doesn't handle negatives yet, doesn't recurse efficiently
*-k = $(eval $(call *-k.configure,$(1),$(2)))$(*-k.result)

#L=111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
#R=111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
#$(info $(L)*$(R) = $(call *,$(L),$(R)))
#$(info $(L)*$(R) = $(call *-k,$(L),$(R)))

define prompt
  $(eval $$(shell printf $(1) >&2))$(eval $(2) := $$(shell head -1))
endef

ifneq ($(filter math,$(MAKECMDGOALS)),)
  $(call prompt,$(subst ,,"operation [+,-,*,>,<>]: "),operation)
  $(call prompt,"lhs (#): ",lhs)
  $(call prompt,"rhs (#): ",rhs)
  $(info result: $(call $(operation),$(lhs),$(rhs)))
.PHONY: math
math: ; @true
endif

define random
$(shell printf "%d" 0x`xxd -l 4 -p /dev/urandom`)
endef

ifneq ($(filter game,$(MAKECMDGOALS)),)

define passages
  $(call prompt,$(subst ,,"you are in a maze of twisty passeges, all alike"),move)
endef

$(eval $(value passages))

game: ; @true

endif

