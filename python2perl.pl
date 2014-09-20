#!/usr/bin/perl -w
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



sub process_line() {
    my $line = $_[0];
    #Subset 0:
	if ($line =~ /^#!/ && $. == 1) {
		# translate #! line 
		print "#!/usr/bin/perl -w\n";
	}
	elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
		# Blank & comment lines can be passed unchanged
		print $line;
	}
	elsif ($line =~ /^(\s*)print\s*"(.*)"\s*$/) {
		# Python's print print a new-line character by default
		# so we need to add it explicitly to the Perl print statement
		#print "print \"$1\", \"\\n\";\n";
		print "$1print \"$2\\n\";\n";
	}
	#subset 1:
=pod
	elsif ($line =~ /^\s*(\w*)\s*=\s*([0-9]*)\s*$/) {
		# Handling simple numarical value or variable assignment
		print "\$"."$1 = $2;\n";
	}
	#elsif ($line =~ /^\s*(\w*)\s*=\s*(\w*)\s*(([\+\-\*\/]+)\s*(\w*)\s*)$/) {
	elsif ($line =~ /^\s*(\w*)\s*[\+\-\*\/]?=\s*([0-9]*)\s*([\+\-\*\/]\s*([0-9]*)\s*)*$/) {
	    # Handling multiple numaric value assignment with +-*/
	    # Handling += -= *= /= as well
	    chomp $line;
		print "\$"."$line;\n";
	}
=cut
	elsif ($line =~ /^\s*(\w*)\s*[\+\-\*\/]?=\s*(\w*)\s*([\+\-\*\/]\s*(\w*)\s*)*$/) {
	    # Handling multiple numaric value and variable assignment with +-*/
	    # Handling += -= *= /= as well
	    chomp $line;
	    $line =~ /^(\s*).*/;
	    $start_space = $1;
	    my @code = &translate_expression($line);
	    print $start_space, @code, ";", "\n";
		#print "\$"."$line;\n";
	}
#=pod
	elsif ($line =~ /^(\s*)print\s*(\w*)\s*([\+\-\*\/]\s*(\w*)\s*)+$/) {
		# Handling direct printing with variable
		# Note the print format is slightly different comparing to that of single print.
		chomp $line;
		&translate_print($line);
	}
#=cut
    # subset 2:
    elsif ($line =~ /^\s*(if|while).*:/) {
		# Handling if statement
		chomp $line;
		my @condition = split (':', $line);
		$condition[0] =~ s/(\s*)(if|while)//;
		my $start_space = $1;
		my $clause = $2;
		my @if_statement = &translate_expression($condition[0]);
		print "$start_space", "$clause \(", "@if_statement", "\) {\n";
		#print "$start_space", &translate_expression($condition[1]), ";\n";
		print &translate_line($condition[1], $start_space);
		print "$start_space", "}\n";
	}
	elsif ($line =~ /^(\s*)print\s*(.*)\s*$/) {
		# Handling direct printing with variable
		print "$1print \"\$$2\\n\";\n";
	}
	#else handling:
	else {
		# Lines we can't translate are turned into comments
		print "#$line\n";
	}
}

sub translate_line(){
    my $line = $_[0];
    my $start_space = $_[1];
    my @expressions = split (';', $line);
    foreach (@expressions) {
        if ($_ =~ /^\s*print/) {
            $_ =~ s/^\s*//;
            &translate_print($_, $start_space);
        }
        else {
            print "$start_space","    ", &translate_expression($_), ";\n";
        }
    }
}

sub translate_expression(){
    my $line = $_[0];
    $line =~ s/\s+/ /g;     #Substitutes the concatenate spaces with one space.
    $line =~ s/^\ //;       #Delete the starting space.
    #print "$line\n";
    my @string = split (' ', $line);
    #print @string, "\n";
    foreach my $variable (@string) {
        #print $string[0], "\n";
        $variable = "\$".$variable if $variable =~ /^[a-zA-z]\w*$/;
        $variable = "\ ".$variable."\ " if $variable =~ /^[\=\+\-\*\/]+$/;
    }
    return @string;
}

sub translate_print(){
    my $line = $_[0];
    my $start_space = $_[1];
    $line =~ s/(^\s*print\s*)//;
	my $prefix = $1;
	#print "!!!$prefix!!!", "\n";
	my @code = &translate_expression($line);
	print "$start_space    ", $prefix, @code, ", \"\\n\"", ";", "\n";
}












