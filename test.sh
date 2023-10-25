#!/bin/bash
set -o nounset
if [ $# -eq 0 ]; then
	echo "Usage: test.sh <question>"
	exit
fi


function summary() {
	IFS=' ' read -r -a array <<< "$g_failed_cases"
	begin=${array[0]}
	end=${array[0]}
	i=1
	len=${#array[@]}
	while [ "$i" -lt "$len" ]; do
		next=${array[$i]}
		prev=${array[$((i - 1))]}
		if [ "$next" -ne "$((prev + 1))" ]; then
			end=$prev
			if [ "$begin" -eq "$end" ]; then
				g_summary="$g_summary$begin "
			else
				g_summary="$g_summary$begin-$end "
			fi
			begin=$next
		fi
		end=$next
		i=$((i + 1))
	done
	if [ "$begin" -eq "$end" ]; then
		g_summary="$g_summary$begin "
	else
		g_summary="$g_summary$begin-$end "
	fi
}

function control_c() {
	if [ -e "$out" ]
	then
		rm -f "$out"
	fi
}

function make_temp() {
	if [ "$(uname)" == "Darwin" ]; then
		out=$(mktemp -t "$PROG")
	else
		out=$(mktemp --suffix="$PROG")
	fi
}

function check_has_function {
  local problem="$1"
  local name="$2"
  local found_func
  if [ "$#" -eq 3 ]
  then
	  local signature="$3"
	  found_func=$(clang-check --ast-dump "$problem".c 2> /dev/null | grep    FunctionDecl | grep " $name " | grep -c "$signature")
  else
	  found_func=$(clang-check --ast-dump "$problem".c 2> /dev/null | grep    FunctionDecl | grep -c " $name " ) 
  fi
  if [ "$found_func" -eq 0 ]
  then
    g_has_function=0
  else
    g_has_function=1
  fi
}

# Check if the student has identified his/herself as author.
# Precond: pwd is the student's repo
# Usage: check_has_author $problem
# Change: g_has_author to 1 if student has changed; 0 otherwise
function check_has_author {
  local problem=$1
  local lines_with_authors
  local no_author
  lines_with_authors=$(grep -E -c @author "$problem".c || true)
  no_author=$(grep -E @author "$problem".c | grep -c XXX || true)
  if [ "$no_author" -eq "$lines_with_authors" ] || [ "$lines_with_authors" -eq  0 ]; then
    g_has_author=0
  else
    g_has_author=1
  fi
}

# Check for Loops
# Precond: pwd is the student's repo
# Usage: check_has_loop $problem
# Change: g_got_loop
function check_has_loop {
  local problem=$1
  got_while=$(clang-check --ast-dump "$problem.c" 2> /dev/null| grep -c WhileStmt)
  got_for=$(clang-check --ast-dump "$problem.c" 2> /dev/null| grep -c ForStmt)
  got_do_while=$(clang-check --ast-dump "$problem.c" 2> /dev/null| grep -c DoStmt)
  if [ "$got_while" -ne 0 ] || [ "$got_for" -ne 0 ] || [ "$got_do_while" -ne 0 ]
  then
    g_has_loop=1
  else
    g_has_loop=0
  fi
}

trap control_c INT

PROG=$1
if [ ! -e "$PROG" ]
then
	echo "$PROG does not exist.  Have you compiled it with make?"
	exit 1
fi

num_failed=0
i=1
g_failed_cases=""
g_summary=" "
while true
do
	if [ -e "inputs/in$i.txt" ] && [ -e "outputs/in$i.txt" ]
	then
		make_temp
		./"$PROG" < "inputs/in$i.txt" | head -c 50MB > "$out"
		status="$?"
		if [ "$status" -ne "0" ]
		then
			echo "$PROG: return non-zero status $status for test case $i"
			num_failed=$((num_failed + 1))
		else 
			if [ -e "$out" ] 
			then
				if [ "$PROG" == "exact-space-needed" ] # TODO replace with name of the program as appropriate
				then
					diff_count=$(diff "$out" "outputs/in$i.txt" | wc -l)
				else
					diff_count=$(diff -bB "$out" "outputs/in$i.txt" | wc -l)
				fi
				if [ "$diff_count" -ne 0 ]
				then
					g_failed_cases="$g_failed_cases $i"
					num_failed=$((num_failed + 1))
				fi
				rm -f "$out"
			else
				echo "$PROG: cannot find output file. Execution interrupted?"
				num_failed=$((num_failed + 1))
			fi
		fi
		i=$((i + 1))
	else
		break
	fi
done

if [ $i -eq 1 ] 
then
	echo "$PROG: no test cases found"
elif [ $num_failed -eq 0 ] 
then
    g_has_function=1
	if [ "$PROG" == "bmi" ]; then
		check_has_function "$PROG" "compute_bmi" "double (double, double)"
		if [ "$g_has_function" -eq 1 ]; then
			echo "$PROG: passed"
		else
			echo "$PROG: failed. The expected function compute_bmi cannot be found"
		fi 
	elif [ "$PROG" == "cuboid" ]; then
		check_has_function cuboid "hypotenuse_of"
		if [ "$g_has_function" -eq 0 ]
		then
			echo "$PROG: failed. The expected function hypotenuse_of cannot be found"
		else
			check_has_function cuboid "area_of_rectangle"
			if [ "$g_has_function" -eq 0 ]
			then
				echo "$PROG: failed. The expected function area_of_rectangle cannot be found"
			else
				echo "$PROG: passed"
			fi
		fi
	else
		echo "$PROG: passed"
	fi
else
	summary
	echo "$PROG: incorrect output for $num_failed test case(s):$g_summary"
fi
# vim:noexpandtab:sw=4:ts=4