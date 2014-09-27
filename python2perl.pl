#!/usr/bin/perl -w
$indentation = "false";
$comma = "false";
$no_need_newline = "false";
%array = ();
%hash = ();
%file = ();
%function = ();

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
#In case the last few "}"s have not been printed when the whole python code is end
if ($indentation eq "true") {
    while (1) {
        print "$last_indentation[-1]}", "\n";
        pop @last_indentation;
        if (@last_indentation == 0) {
            $indentation = "false";
            last;
        }
    }
}
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
    # remove the last ;
    $line =~ s/;(\s*)$/$1/;
    if ($line =~ /^\s*$/) {
		# Blank lines can be passed unchanged
		print $line;
		return;
	}
    # Higher priorities:
    # xxx.readlines()
    elsif ($line =~ /(\s*)(\w*)\s*=\s*(.+)\.readlines\(\)\s*$/) {
        my $result = $3;
        $result = "STDIN" if $result eq "sys.stdin";
		print "$1\@$2 = (<$result>);";
		++$array{$2};
	}
	# normal open()
    elsif ($line =~ /(\s*)(\w*)\s*=\s*open\((.*)\)\s*$/) {
        print $1;
        &do_open($3, $2);
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
	# re.sub
    elsif ($line =~ /^(\s*)(.*)re.sub\(\s*r\'(.+)\'\s*,\s*\'(.*)\'\s*,\s*(.+)\)\s*$/) {
        my $space = $1;
        my $prefix_expression = $2;
        my $first = $3;
        my $second = $4;
        my $object = &translate_single_expression($5);
        my @result = &translate_expression($prefix_expression);
        #print $expression[1], "\n";
		print "$space", "$object =~ s/$first/$second/g;";
		if ($prefix_expression) {
		    if ($result[0] ne "$object") {
                print "\n$space", "@result", " $object;"
            }
        }
	}
#=pod
	# re.search
    elsif ($line =~ /(\s*)(\w*)\s*=\s*re.search\((.+),\s*(.+)\)\s*$/) {
        my $a = $1;
        my $b = $2;
        my $c = $3;
        my $d = $4;
        $c =~ s/^r\'//;
        $c =~ s/\'$//;
        #print $expression[1], "\n";
		print "$a\@$b = \$$d =~ /$c/g;";
		++$array{$b};
	}
#=cut
	# No initialisation is needed for array in perl if the  array is empty.
	elsif ($line =~ /^\s*(\w+)\s*=\s*\[\s*\]\s*/){
	    ++$array{$1};
	    return if !$comment;
	}
	# initialisation array.
	elsif ($line =~ /^(\s*)(\w+)\s*=\s*\[([\w,]+)\]\s*/){
	    ++$array{$2};
	    print "$1\@$2 = \($3\);";
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
	elsif ($line =~ /^(\s*)(\w+)\s*=\s*(\w+)\.split\('(.*)'\)\s*$/) {
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
	# sys.stdout.write()
	elsif ($line =~ /^(\s*)sys.stdout.write\("(.*)"\)\s*$/) {
		print "$1print \"$2\";";
	}
	
	#subset 1:
	# Majority of assignment expression can be dealed with by the following lines.
	elsif ($line =~ /^\s*([\w\[\]\.\(\)]*)\s*[\+\-\*\/]?=.*$/) {
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
    elsif ($line =~ /^(\s*)if\s*(\w+)\s*\w*\s*in\s*(.+):\s*$/) {
        my $a = $1;
        my $b = $2;
        my $c = $3;
	    $indentation = "true";
	    push @last_indentation, $a;
	    my $result = &translate_single_expression($c);
	    $result =~ s/%/\$/;
	    if ($line =~ /\snot\s/) {
	        print "$a", "if \(!$result\{\$$b\}\) {";
	    }
	    else {
	        print "$a", "if \($result\{\$$b\}\) {";
	    }
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
		my @statement;
		#print "$condition[0]\n";
		if ($condition[0] =~ /^(.+)\s*is not None$/) {
		    #print "$1\n";
		    @statement = &translate_expression($1);
		    #print "!!@statement!!\n";
		    @statement = "!".$statement[0];
		}
		else {
		    @statement = &translate_expression($condition[0]);
	    }
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
	    my $start_space = $1;
	    $line =~ s/\[1:\]/\[1!!\]/;
		chomp $line;
		my @condition = split (':', $line);
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
	elsif ($line =~ /^(\s*)(\w+).append\((.+)\)\s*$/) {
	    print "$1push \@$2, \$$3;";
	}
	# Subset 5:
	# pop
	elsif ($line =~ /^(\s*)(\w+).pop\(\)\s*$/) {
	    print "$1pop \@$2;";
	}
	# function definition
	elsif ($line =~ /^(\s*)def\s+(\w+)\((.*)\):\s*$/) {
	    print $1, "sub $2\(\) {";
	    if ($3) {
	        my @arguments = split (',', $3);
	        foreach $i (0..@arguments-1) {
	            print "\n$1    ", &translate_single_expression($arguments[$i]),
	            " = \$_\[$i\]", ";";
	        }
	    }
	    ++$function{$2};
	    $indentation = "true";
        push @last_indentation, $1;
	}
	# function calling
	elsif ($line =~ /^(\s*)(\w+)\((.*)\)\s*$/ && $function{$2}) {
	    print $1, "&$2\(";
	    my @arguments = split (',', $3);
	        foreach $i (0..@arguments-1) {
	            print &translate_single_expression($arguments[$i]);
	            print ", " if $i != @arguments-1;
	        }
        print "\);";
	}
	# function return
	elsif ($line =~ /(\s*)return\s*(.*)/) {
        print "$1return ", &translate_expression($2), ";";
	}
	
	
    
	elsif ($line =~ /^\s*import.*/){
	    return if !$comment;
	}
	#else handling:
	else {
		# Lines we can't translate are turned into comments
		chomp $line;
		print "#$line   #match error, can't translate this line.\n";
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
    # for-loop with sys.argv[]
    elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*(sys.argv\[.+\]:)\s*$/) {
        my $result = &handling_sys($3);
        print "$1foreach \$$2 \($result\) {";
    }
    # for-loop with variable
    elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*(\w+):\s*$/) {
	    print "$1foreach \$$2 (\@$3) {";
	}
	# for-loop with sorted key
    elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*sorted\(([\w\[\]]+)\.keys\(\)\):\s*$/) {
        my $result = &translate_single_expression($3);
	    print "$1foreach \$$2 (sort keys $result) {";
	}
	# for-loop with fileinput.input()
	elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*fileinput.input\(\):\s*$/) {
	    print "$1while (\$$2 = <>) {";
	}
	# for-loop with open()
	elsif ($line =~ /^(\s*)for\s*(\w+)\s*in\s*open\((.*)\):\s*$/) {
	    my $handler_name = &do_open($3);
	    print "$1while (\$$2 = <$handler_name>) {";
	}
	else {
	    print "#$line   #for line error.";
	}
}

sub do_open() {
    my @command = split (',', $_[0]);
    my $mode = "";
    $mode = " ".$command[1]."," if $command[1];
    my $open_file = &translate_single_expression($command[0]);
    my $file_name = $open_file;
    $file_name =~ s/\"//g;
    my $handler_name = "F";
    $handler_name = $_[1] if $_[1];
    my $i = 1;
    while ($file{$handler_name}) {
        $handler_name = "F"."$i";
        ++$i;
    }
    ++$file{$handler_name};
    print "open $handler_name,", $mode, " $open_file or die \"\$0: can not open $file_name: \$!\";";
    print "\n" if !$_[1];
    return $handler_name;
}

sub second_range(){
    my @result = &translate_expression($_[0]);
    if (@result == 1 && $result[-1] eq "\@ARGV") {
        ;
    }
    elsif (@result == 1 && !$result[-1] =~ /^\$/) {
        --$result[-1];
    }
    elsif($result[-2] && $result[-2] eq "+" && $result[-1] == 1) {
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
    #print "^$line^\n";
    if ($line =~ /\".*\"/) {
        $line =~ s/\"/\$!!\$\"/;
        my @parts = split ('\$!!\$', $line);
        my @string = &translate_expression($parts[0]);
        $string[@string] = &translate_single_expression($parts[1]);
        return @string;
    }
    # join should only have 2 arguments.
    elsif ($line =~ /(.+)\.join\((.+)\)/) {
        my $result = "join\(".&translate_single_expression($1).", ".&translate_single_expression($2)."\)";
        return $result;
    }
    # list[]
    elsif ($line =~ /^\w+\[[^,.]+\]$/) {
        my @string;
        $string[0] = &translate_single_expression($line);
        return @string;
    }
    # function calling with return value
	elsif ($line =~ /^(\s*)(\w+\s*=\s*)(\w+)\((.*)\)\s*$/ && $function{$3}) {
	    #print "here\n";
	    my @string = &translate_expression($2);
	    push @string, "&$3\(";
	    my @arguments = split (',', $4);
	        foreach $i (0..@arguments-1) {
	            $string[-1] .= &translate_single_expression($arguments[$i]);
	            $string[-1] .= ", " if $i != @arguments-1;
	        }
        $string[-1] .= "\)";
        return @string;
	}
    # If there is no space between operators and variables or numeric values.
    #print "!!$line!!\n";
    $line =~ s/(\w+)([=+\-*\/|><%^&~,!]+)/$1 $2 /g;
    $line =~ s/\s+/ /g;     #Substitutes the concatenate spaces with one space.
    $line =~ s/^\ //;       #Delete the starting space.
    $line =~ s/\ $//;       #Delete the ending space.
    #print ">>$line<<\n";
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
    $expression =~ s/\s*,?$//;
    $expression =~ s/^\s*//;
    if ($expression =~ /^(int|float|double)\((.*)\)/){
        #print $variable, "\n";
        $expression = &handling_cast($expression);
        #print $variable, "\n";
    }
    if ($expression =~ /^len\((.+)\)$/) {
        if ($1 eq "sys.argv") {
            $expression = "\@ARGV";
        }
        elsif($array{$1}) {
    	    $expression = "\@$1";
        }
	    else {
            $expression = "length(\$$1)";
        }
    }
    # string ".*"
    elsif ($expression =~ /\".*\"/) {
        #$expression =~ s/^\"//;
        #$expression =~ s/\"$//;
    }
    # sys.*
    elsif ($expression =~ /^sys\..+$/) {
        $expression = &handling_sys($expression);
	}
    # .group
    elsif ($expression =~ /^(\w*)\.group\((\d*)\)$/) {
        if ($2 == 0) {
            $expression = "\@$1";
        }
        else {
            my $index = "";
            $index = $2 - 1 if $2 ne "";
            $expression = "\$$1\[$index\]";
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
        #print "^^$expression^^\n";
        if ($array{$expression}) {
            $expression = "\@".$expression;
            return $expression;
        }
        if ($hash{$expression}) {
            $expression = "%".$expression;
            return $expression;
        }
        $expression = "\$".$expression;
        #print "^^!$expression!^^\n";
    }
    # only if the segment of array or hash, which is the [.+]
    elsif ($expression =~ /^\[(.+)\]$/) {
        #print "^$expression^\n";
        #print "^$1^\n";
        $expression = "\[".&translate_single_expression($1)."\]";
        #print "^!^!$expression!^!^\n";
    }
    # multiple list and hash
    elsif ($expression =~ /^(\w+)\[.+\]\[.+\]+$/) {
        #print "!$expression!\n";
        my $name = $1;
        my @result = &translate_nested($expression, '[]');
        #print "---!@result!---\n";
        foreach $e (@result) {
            $e = &translate_single_expression($e);
            #print "^$e^\n";
        }
        if ($hash{$name}) {
            foreach $i (1..@result-1) {
                $result[$i] =~ s/^\[(.+)\]$/\{$1\}/;
            }
            $expression = join('', @result);
            #print "!$expression!\n";
        }
    }
    # list and hash
    elsif ($expression =~ /^(\w+)\[(.+)\]$/) {
        #print "!$expression!\n";
        my $name = $1;
        my $menber_expression = &translate_single_expression($2);
        if ($array{$name}) {
            #$expression =~ s/([a-zA-Z]\w*)/\$$1/g;
            $expression = "\$$name\[$menber_expression\]";
        }
        elsif ($hash{$name}) {
            $expression = "\$$name\{$menber_expression\}";
            #print "!$expression!\n";
        }
    }
    # python operator <>
    elsif ($expression eq "<>") {
        $expression = "<=>";
    }
    #print $expression, "\n";
    return $expression;
}

sub translate_nested() {
    my $line = $_[0];
    my @symbol = split ('', $_[1]);
    #print "$line\n";
    #print "$symbol[1]\n";
    my @result = split ('', $line);
    my $counter = 0;
    my $flag = "false";
    foreach $i (0..@result-2) {
        if ($result[$i] eq $symbol[0]) {
            ++$counter;
            $flag = "true";
        }
        --$counter if $result[$i] eq $symbol[1];
        if ($flag eq "true" && $counter == 0) {
            $result[$i] .= "\$!!\$";
            $flag = "false";
        }
    }
    my $string = join('', @result);
    @result = split ('\$!!\$' ,$string);
    #print "@result\n";
    return @result;
}

sub translate_print(){
    my $line = $_[0];
    #print "!$line!", "\n";
    $line =~ s/\s*;?$//;
    my $start_space = "";
    if ($_[1]) {
        $start_space = $_[1];
    }
    $line =~ s/(^\s*print\s*)//;
	my $prefix = $1;
	#print "!!!$prefix!!!", "\n";
	#print "$line\n";
	my @code = &translate_expression($line);
	#print "~~@code~~\n";
	# if python printing with ',' at the end of line
	if ($line =~ /,$/) {
	    $code[-1] =~ s/,$//;
	    print "$start_space", $prefix, @code, ";";
	    return;
	}
	# if print nothing, it ment to be print a new line.
	elsif ($line eq "") {
	    print "$start_space", $prefix, " \"\\n\";";
	    return;
	}
	# print list should be treated specially.
    elsif (@code == 1 && $code[0] =~ /^\@/) {
	    print "$start_space", $prefix, "\"@code\\n\";";
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
    elsif ($line =~ /^\s*sys.argv\[(.*)\]:?\s*/) {
        if ($1 eq "1!!" || $1 eq "1:") {
            $line = "\@ARGV";
        }
        else {
            my $result;
            if ($1 =~ /\d+/) {
                $result = $1 - 1;
            }
            else {
                $result = "\$$1 - 1";
            }
            $line = "\$ARGV\[$result\]";
        }
    }
	return $line;
}










