#!/usr/bin/perl

use Template;

my $metadata = {
    'Project_ID' => 233483,
    'Project_Name' => "Hairy projecct"
};

my $tt = Template->new({INTERPOLATE => 1}) || die;

my $template = 'template.xml';

print "Here it comes\n";

$tt->process('template.xml', $metadata) || die("Template error " , $tt->error());
