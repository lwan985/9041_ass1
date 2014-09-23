#!/usr/bin/perl -w
$indentation = "false";
$comma = "false";
$no_need_newline = "false";
%array = ();
%hash = ();

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
    if ($line =~ /^#!/ && $. == 1) {
		# translate #! line 
		print "#!/usr/bin/perl -w\n";
		return;
	}
	elsif ($line =~ /^\s*#/) {
		# comment lines can be passed unchanged
		print $line;
		return;
	}
	# Else, should be an normal line, lots of choices.
    my $line = $_[0];
    # Save the tail comment and print back at the end of whole process
    $line =~ s/(\s*#.*)$//;
    $comment = $1;
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
    if ($line =~ /^\s*$/) {
		# Blank lines can be passed unchanged
		print $line;
		return;
	}
    # Higher priorities:
    # sys.stdin.readlines()
    elsif ($line =~ /(\s*)(\w*)\s*=\s*sys.stdin.readlines\(\)\s*$/) {
		print "$1\@$2 = (<STDIN>);";
		++$array{$2};
	}
	# re.match
    elsif ($line =~ /(\s*)(\w*)\s*=\s*re.match\((.+),\s*(.+)\)\s*$/) {
        my $a = $1;
        my $b = $2;
        my $c = $3;
        my $d = $4;
        $c =~ s/^r\'//;
        $c =~ s/\'$//;
        #print $expression[1], "\n";
		print "$a\@$b = \$$d =~ /$c/;";
		++$array{$b};
	}
	# No initialisation is needed for array in perl.
	elsif ($line =~ /^\s*(\w+)\s*=\s*\[\s*\]\s*/){
	    ++$array{$1};
	    return if !$comment;
	}
	# Initialisation of hash could be implemented in perl.
	elsif ($line =~ /^\s*(\w+)\s*=\s*{\s*}\s*/){
	    ++$hash{$1};
	    return if !$comment;
	}
	# Multiple command in one line:
	elsif (!($line =~ /:/) && $line =~ /(\s*)\S+\s*;\s*\S+/){
        chomp $line;
        &translate_line($line, $1);
        $no_need_newline = "true";
	}
	# split('')
	elsif ($line =~ /^(\s*)(\w+)\s*=\s*(\w+)\.split\('(.)'\)\s*$/) {
	    my $a = $1;
	    my $b = $2;
	    my $c = $3;
	    my $char = $4;
	    $char = "\\$char" if $char =~ /[\|\/\\\.\-]/;
	    print "$a\@$b = split /$char/, \$$c;";
	    ++$array{$b};
	}
    # Handling print & Subset 0:
    # print with "", just leave it to simple hanling.
	elsif ($line =~ /^(\s*)print\s*"(.*)"\s*$/) {
		# Python's print print a new-line character by default
		# so we need to add it explicitly to the Perl print statement
		print "$1print \"$2\\n\";";
		$comma = "false";
	}
	# print with %, slightly different.
	elsif ($line =~ /^(\s*)print\s*"(.*)"\s*%\s*(.+)\s*$/) {
		# print with %, format printing:
		my $a = $1;
		my $b = $2;
		my $c = $3;
		#print "here\n";
		$c =~ s/^\((.+)\)$/$1/;
		my @result = &translate_expression($c);
		for $i (0..$#result - 1){
		    $result[$i] .= ",";
		}
		print "$a", "printf \(\"", $b, "\\n\", ", "@result", "\);";
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
		print "$1print \"$2\";";
	}
	
	#subset 1:
	# Majority of assignment expression can be dealed with by the following lines.
	elsif ($line =~ /^\s*([\w\[\]]*)\s*[\+\-\*\/]?=.*$/) {
	    # Handling multiple numaric value and variable assignment with +-*/
	    # Handling += -= *= /= as well
	    #print "here\;\n";
	    chomp $line;
	    $line =~ s/;$//;    # Remove the tail ';' in python code.
	    $line =~ /^(\s*).*/;
	    $start_space = $1;
	    my @code = &translate_expression($line);
	    #print "#@code#\n";
	    print $start_space, "@code", ";";
		#print "\$"."$line;\n";
	}
    # if statement about hash key
    elsif ($line =~ /^(\s*)if\s*(\w+)\s*in\s*(\w+):\s*$/) {
	    $indentation = "true";
	    push @last_indentation, $1;
	    print "$1if \(\$$3\{\$$2\}\) {";
	}
	# subset 2:
    elsif ($line =~ /^\s*(if|while|elif|else if).*:/) {
		# Handling statement
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
		print "$start_space", "$clause \(", "@statement", "\) {";
		#print "$start_space", &translate_expression($condition[1]), ";\n";
		# Little trick, in case the condition[1] is only spaces (\s*).
		$condition[1] =~ s/(\s*)// if $condition[1];
		if ($condition[1]) {
		    print "\n";
		    print &translate_line($condition[1], $start_space);
		    #print "$start_space", "#\n#$start_space}";
		    print "$start_space", "}";
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
		print "$start_space", "else {";
		$indentation = "true";
        push @last_indentation, $start_space;
	}
	# Handling for-loop
	elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*.*:.*$/) {
	    # Handling statement
		chomp $line;
		my @condition = split (':', $line);
		my $start_space = $1;
		# print different foreach statement
		&handle_in($line);
		if ($condition[1]) {
		    print "\n";
		    print &translate_line($condition[1], $start_space);
		    #print "$start_space", "#\n#$start_space}";
		    print "$start_space", "}";
		}
		else {
		    $indentation = "true";
	        push @last_indentation, $start_space;
		}
	}
	# Handling break and continue
	elsif ($line =~ /^(\s*)(break|continue)\s*$/) {
	    if ($2 eq "break") {
	        $the_line = "last";
	    }
	    else {
	        $the_line = "next";
	    }
	    print "$1", "$the_line;";
	}
	# Subset 4:
	# append string
	elsif ($line =~ /^(\s*)(\w+).append\((\w+)\)\s*$/) {
	    print "$1push \@$2, \$$3;";
	}
	# Subset 5:
	
	
	
    
	elsif ($line =~ /^\s*import.*/){
	    return if !$comment;
	}
	#else handling:
	else {
		# Lines we can't translate are turned into comments
		print "#$line";
	}
	print $comment if $comment;
	if ($no_need_newline eq "true") {
	    $no_need_newline = "false";
	    return;
	}
	print "\n";
}

sub handle_in() {
    my $line = $_[0];
    # for-loop with in range()
	if ($line =~ /^(\s*)for\s*(\w+)\s*in\s*range\((.+),\s*(.+)\):.*$/) {
	    print "$1foreach \$$2 (", &translate_expression($3), "..", &second_range($4), ") {";
    }
    # for-loop with sys.stdin
    elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*sys.stdin:\s*$/) {
        print "$1foreach \$$2 (<STDIN>) {";
    }
    # for-loop with variable
    elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*(\w+):\s*$/) {
	    print "$1foreach \$$2 (\@$3) {";
	}
	# for-loop with sorted key
    elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*sorted\((\w+)\.keys\(\)\):\s*$/) {
	    print "$1foreach \$$2 (sort keys %$3) {";
	}
	# for-loop with fileinput.input()
	elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*fileinput.input\(\):\s*$/) {
	    print "$1while (\$$2 = <>) {";
	}
	else {
	    print "#$line";
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
    $line =~ s/;\s*$//;
    my @expressions = split (';', $line);
    foreach (@expressions) {
        if ($_ =~ /^\s*print/) {
            $_ =~ s/^\s*//;
            &translate_print($_, "$start_space    ");
        }
        elsif ($_ =~ /sys.stdout.write\((.+)\)/) {
            #print "matched\n";
            my $string = $1;
            #print $_, "\n";
            if ($string =~ /\"(\w+)\"/) {
                print "$start_space    ", "print \"$1\";\n";
            }
            #.."
            else{
                print "$start_space    ", "print \$$string;\n";
            }
        }
        else {
            my @result = &translate_expression($_);
            print "$start_space    ", "@result", ";\n";
        }
    }
}

sub translate_string() {
    my $line = $_[0];
}

sub translate_expression() {
    my $line = $_[0];
    #print $line, "\n";
    #if ($line =~ /\".*\"/) {
    #    return &translate_string($line);
    #}
    # If there is no space between operators and variables or numeric values.  
    #print "$line\n";
    $line =~ s/([=+\-*\/|><%^&~,]+)(\w)/ $1 $2/g;
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
    # .group
    elsif ($expression =~ /^(\w*)\.group\((\d)\)$/) {
        my $index = $2 - 1;
        $expression = "\$$1\[$index\]";
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
        if ($array{$expression}) {
            $expression = "\@".$expression;
            return $expression;
        }
        $expression = "\$".$expression;
    }
    # list and hash
    elsif ($expression =~ /^(\w+)\[(\w+)\]/) {
        #print "!$expression!\n";
        my $name = $1;
        my $menber = $2;
        if ($array{$name}) {
            $expression =~ s/([a-zA-Z]\w*)/\$$1/g;
        }
        elsif ($hash{$name}) {
            $expression = "\$$name\{\$$menber\}";
        }
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
	    print "$start_space    ", $prefix, @code, ";";
	    return;
	}
	# if print nothing, it ment to be print a new line.
	elsif ($line eq "") {
	    print "$start_space", $prefix, " \"\\n\";";
	    return;
	}
	# Else, print the print expression.
	print "$start_space", $prefix, "@code", ", \"\\n\";";
	# Little trick here!!!
	# If the print is coming from tail commmand not from a single line itself,
	# then add an new line. As normal expression handler will automatically add \n
	# Damn bug!
	if ($comment) {
	    print $comment;
	    $comment = "";
	}
	print "\n" if $_[1];
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










