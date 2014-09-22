#!/usr/bin/perl -w
$indentation = "false";
$comma = "false";
%array = ();
if (@ARGV == 1) {
    #print $ARGV[0];
    open ($F, $ARGV[0]);
    while ($line = <$F>) {
        &process_line($line);
    }
}
else {
    while ($line = <>) {
        &process_line ($line);
    }
}
#In case the last "}" has not been printed when the whole python code is end
print "}\n" if $indentation eq "true";
#print "print \"\\n\";\n" if $comma eq "true";


sub process_line() {
    my $line = $_[0];
    # Deal with the indentation problem
    $line =~ s/\t/    /g;
    if ($indentation eq "true") {
        #print "here!!\n";
        $line =~ /^(\s*)(.*)/;
        my $now_indentation = $1;
        my $count1 = $now_indentation =~ tr/ //;
        $count1 = 0 if (!$2);
        my $count2 = $last_indentation[-1] =~ tr/ //;
        while ($count1 <= $count2) {
            print "$last_indentation[-1]}", "\n";
            pop @last_indentation;
            if (@last_indentation == 0) {
                $indentation = "false";
                last;
            }
            $count2 = $last_indentation[-1] =~ tr/ //;
        }
    }
    if ($line =~ /^#!/ && $. == 1) {
		# translate #! line 
		print "#!/usr/bin/perl -w\n";
	}
	elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
		# Blank & comment lines can be passed unchanged
		print $line;
	}
    # Higher priorities:
    # sys.stdin.readlines()
    elsif ($line =~ /(\s*)(\w*)\s*=\s*sys.stdin.readlines\(\)\s*$/) {
		print "$1\@$2 = (<STDIN>);\n";
		++$array{$2};
	}
	# No initialisation is needed for array in perl.
	elsif ($line =~ /^\s*(\w+)\s*=\s*\[\]\s*/){
	    ++$array{$1};
	}  
    # Handling print & Subset 0:
    # print with "", just leave it to simple hanling.
	elsif ($line =~ /^(\s*)print\s*"(.*)"\s*$/) {
		# Python's print print a new-line character by default
		# so we need to add it explicitly to the Perl print statement
		print "$1print \"$2\\n\";\n";
		$comma = "false";
	}
	# print with %, slightly different.
	elsif ($line =~ /^(\s*)print\s*"(.*)"\s*%\s*(\w+)\s*$/) {
		# print with %, format printing:
		print "$1printf \(\"", $2, "\\n\", ", &translate_expression($3), "\);\n";
		$comma = "false";
	}
	# the rest of print, only deal with line start with print. (No tail print)
	elsif ($line =~ /^\s*print/) {
		# Handling multiple printing type
		chomp $line;
		&translate_print($line);
		$comma = "false";
	}
	elsif ($line =~ /^(\s*)sys.stdout.write\("(.*)"\)\s*$/) {
		print "$1print \"$2\";\n";
	}
	#subset 1:
	elsif ($line =~ /^\s*(\w*)\s*[\+\-\*\/]?=.*$/) {
	    # Handling multiple numaric value and variable assignment with +-*/
	    # Handling += -= *= /= as well
	    chomp $line;
	    $line =~ /^(\s*).*/;
	    $start_space = $1;
	    my @code = &translate_expression($line);
	    print $start_space, "@code", ";", "\n";
		#print "\$"."$line;\n";
	}
    # subset 2:
    elsif ($line =~ /^\s*(if|while|elif|else if).*:/) {
		# Handling if statement
		chomp $line;
		my @condition = split (':', $line);
		#$condition[0] =~ s/(\s*)(if|while|elif|else if)\s*\(?(.+)\):/$3/;
		$condition[0] =~ s/(\s*)(if|while|elif|else if)//;
		my $start_space = $1;
		my $clause = $2;
		$condition[0] =~ s/^\s*\((.+)\)\s*$/$1/;
		#print $condition[0], "\n";
		$clause =~ s/(elif|else if)/elsif/;
		my @statement = &translate_expression($condition[0]);
		print "$start_space", "$clause \(", "@statement", "\) {\n";
		#print "$start_space", &translate_expression($condition[1]), ";\n";
		if ($condition[1]) {
		    print &translate_line($condition[1], $start_space);
		    print "$start_space", "}\n";
		}
		else {
		    $indentation = "true";
	        push @last_indentation, $start_space;
		}
	}
	# subset 3:
	elsif ($line =~ /^(\s*)else:\s*$/) {
		# Handling else
		chomp $line;
		my $start_space = $1;
		print "$start_space", "else {\n";
		$indentation = "true";
        push @last_indentation, $start_space;
	}
	# Handling for-loop
	elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*range\((.+),\s*(.+)\):\s*$/) {
	    $indentation = "true";
	    push @last_indentation, $1;
	    #my $num = $4 - 1;
	    print "$1foreach \$$2 (", &translate_expression($3), "..", &second_range($4), ") {\n";
	}
	# Handling break and continue
	elsif ($line =~ /^(\s*)(break|continue)\s*$/) {
	    if ($2 eq "break") {
	        $the_line = "last";
	    }
	    else {
	        $the_line = "next";
	    }
	    print "$1", "$the_line;\n";
	}
	# Subset 4:
	# for-loop with sys.stdin
	elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*sys.stdin:\s*$/) {
	    $indentation = "true";
	    push @last_indentation, $1;
	    print "$1foreach \$$2 (<STDIN>) {\n";
	}
	# append string
	elsif ($line =~ /^(\s*)(\w+).append\((\w+)\)\s*$/) {
	    print "$1push \@$2, \$$3;\n";
	}
	
	
    
	elsif ($line =~ /^\s*import.*/){
	    ;
	}
	#else handling:
	else {
		# Lines we can't translate are turned into comments
		print "#$line\n";
	}
}

sub second_range(){
    my @result = &translate_expression($_[0]);
    if (@result == 1) {
        --$result[-1];
    }
    elsif($result[-2] eq "+" && $result[-1] == 1) {
        $result[-2] = "";
        $result[-1] = "";
    }
    else {
        $result[-1] .= " - 1";
    }
    return @result;
}

sub translate_line(){
    my $line = $_[0];
    my $start_space = $_[1];
    my @expressions = split (';', $line);
    foreach (@expressions) {
        if ($_ =~ /^\s*print/) {
            $_ =~ s/^\s*//;
            &translate_print($_, "$start_space    ");
        }
        else {
            my @result = &translate_expression($_);
            print "$start_space    ", "@result", ";\n";
        }
    }
}

sub translate_expression(){
    my $line = $_[0];
    #print $line, "\n";
    # If there is no space between operators and variables or numeric values.  
    $line =~ s/([=+\-*\/|><%^&~]+)(\w)/ $1 $2/g;
    $line =~ s/\s+/ /g;     #Substitutes the concatenate spaces with one space.
    $line =~ s/^\ //;       #Delete the starting space.
    $line =~ s/\ $//;       #Delete the ending space.
    #print "$line\n";
    my @string = split (' ', $line);
    # Lots of possibilities.
    return &translate_single_expression($string[0]) if @string == 1;
    foreach my $expression (@string) {
        $expression = &translate_single_expression($expression);
    }
    return @string;
}

sub translate_single_expression() {
    my $expression = $_[0];
    #print $expression, "\n";
    $expression =~ s/,$//;
    if ($expression =~ /^(int|float|double)\((.*)\)/){
        #print $variable, "\n";
        $expression = &handling_cast($expression);
        #print $variable, "\n";
    }
    if ($expression =~ /^len\((.+)\)$/) {
        if($array{$1}) {
    	    $expression = "\@$1";
        }
	    else {
            $expression = "length(\$$1)";
        }
    }
    # continue, break
    elsif ($expression =~ /^(break|continue)$/) {
        $expression = "last" if $1 eq "break";
        $expression = "next" if $1 eq "continue";
	}
    # and, or, not
    elsif ($expression =~ /^(and|or|not)$/) {
        ;
    }
    # variable
    elsif ($expression =~ /^[a-zA-Z]\w*$/) {
        $expression = "\$".$expression;
    }
    # list
    elsif ($expression =~ /^\w+\[(\w+)\]/) {
        $expression =~ s/([a-zA-Z]\w*)/\$$1/g;
    }
    # python operator <>
    elsif ($expression eq "<>") {
        $expression = "<=>";
    }
    #print $expression, "\n";
    return $expression;
}

sub translate_print(){
    my $line = $_[0];
    #print "!$line!", "\n";
    my $start_space = "";
    if ($_[1]) {
        $start_space = $_[1];
    }
    $line =~ s/(^\s*print\s*)//;
	my $prefix = $1;
	#print "!!!$prefix!!!", "\n";
	my @code = &translate_expression($line);
	# if python printing with ',' at the end of line
	if ($line =~ /,$/) {
	    $code[-1] =~ s/,$//;
	    print "$start_space    ", $prefix, @code, ";", "\n";
	    return;
	}
	# if print nothing, it ment to be print a new line.
	elsif ($line eq "") {
	    print "$start_space", $prefix, " \"\\n\";", "\n";
	    return;
	}
	# Else, print every expression.
	print "$start_space", $prefix, "@code", ", \"\\n\";\n";
}

sub handling_cast() {
    my $line = $_[0];
    $line =~ /^(int|float|double)\((.*)\)/;
	$line = $2;
	if ($line) {
	    return &handling_sys($line);
    }
    else {
        return $line;
    }
}

sub handling_sys() {
    my $line = $_[0];
    if ($line eq "sys.stdin.readline\(\)") {
        $line = "\<STDIN\>";
    }
	return $line;
}










