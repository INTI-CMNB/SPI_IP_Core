#!/usr/bin/perl
##############################################################################
#
# Copyright (c) 2010 Francisco Salomón <fsalomon en inti gov ar>
# Copyright (c) 2010 Salvador E. Tropea <salvador en inti gov ar>
# Copyright (c) 2010 Instituto Nacional de Tecnología Industrial
#
##############################################################################
#
# Description:
#  This script gets a list of generics for which you want to synthesize the
# core from a file in csv form as follow:
# 
#    GEN_1, GEN_2
#    val_1_g1,  val_1_g2
#    val_2_g1,  val_2_g2
#    ...
# 
#  Using this information and taking as dependencies the generic list and
# the $project.xilprj file and its 'includes', the script builds a makefile
# $project.sub.mak with a target that executes the commands to perform the
# synthesis for each set of values of generics. The makefile will seem as
# follow.
# 
#    #!/usr/bin/make
#    DEPE=\
#    	../../../YY/XX/include1.vhdl\
#    	...
#    	$project.vhdl project.xilprj
#    
#    all: $project.txt
#    
#    $project.txt: $(DEPE)
#    	#New parameters set
#    	rm -f *.in.xst
#    	@echo "Synthesis for generics:"                   >> $(PRJ).txt
#    	@echo "         GEN_1=VAL_1_G1"                   >> $(PRJ).txt
#    	@echo "         GEN_2=VAL_1_G2"                   >> $(PRJ).txt
#    	@echo "--------------------------------------"    >> $(PRJ).txt
#    	@echo "-generics {GEN_1=VAL_1_G1 GEN_2=VAL_1_G2}" >> $(PRJ).in.xst
#    	xil_project.pl --no-standalone --make $(PRJ).xilprj
#    	#New parameters set
#    	rm -f *.in.xst
#    	@echo "Synthesis for generics:"                   >> $(PRJ).txt
#    	@echo "         GEN_1=VAL_2_G1"                   >> $(PRJ).txt
#    	@echo "         GEN_2=VAL_2_G2"                   >> $(PRJ).txt
#    	@echo "--------------------------------------"    >> $(PRJ).txt
#    	@echo "-generics {GEN_1=VAL_2_G1 GEN_2=VAL_2_G2}" >> $(PRJ).in.xst
#    	xil_project.pl --no-standalone --make $(PRJ).xilprj
#    	...
#
##############################################################################
use Getopt::Long;
# Generic names ready
$genNames = 0;
# Default working directory depth
$dirLevel=3;

# Parse command line
ParseCommandLine();
# Set sub makefile
open (SUBMAK, ">$submak") or die ("Could not open $submak!");
print SUBMAK "\#!/usr/bin/make\n";
# Set dependencies
# If no force option, include dependencies
unless ($force){
   # First, generate project files for get dependencies from $prjfile
   system("xil_project.pl --no-standalone $xilprjfile");
   open (PRJFILE, "$prjfile") or die ("Could not open $prjfile");
   while ($line = <PRJFILE>)
   {
     unless ($line =~ /^$/){
       chomp($line);
       @fielddata = split ' ', $line;
       $lastitem = scalar(@fielddata)-1;
       push @allSrc, @fielddata[$lastitem];
     }
   }
   close(PRJFILE);
   # Set its dependencies
   print SUBMAK "DEPE=\\\n";
   $counter=0;
   foreach $f (@allSrc)
      {
       print SUBMAK "\t$f\\\n";
       $counter++;
      }
   print SUBMAK "\t$xilprjfile $genlist\n";
   print SUBMAK "\nall: $projrep\n\n";
   print SUBMAK "$projrep: \$(DEPE)\n";
}
else{
   print SUBMAK "\nall: $projrep\n\n";
   print SUBMAK ".PHONY: $projrep\n\n";
   print SUBMAK "$projrep: \n";
}
# Evaluate generic list, get a makefile and run make for all!
open (GENLIST, $genlist) or die ("Could not open $genlist!");
while ($line = <GENLIST>)
{
  unless ($line =~ /^$/){
    chomp($line);
    $line =~ s/ //g;
    if ($genNames == 0){
      $genNames=1;
      @fieldparam = split ',', $line;
    }
    else{
      #set header for report
      @fieldvalue = split ',', $line;
      print SUBMAK "\t\#New parameters set\n";
      print SUBMAK "\trm -f *.in.xst\n";
      print SUBMAK "\t\@echo \"Synthesis for generics:\"  >> $projrep\n";
      $counter = 0;
      foreach(@fieldparam){ #@fieldparam[$counter]=@fieldvalue[$counter]
         print SUBMAK "\t\@echo \"   @fieldparam[$counter]=";
         print SUBMAK "@fieldvalue[$counter]\" >> $projrep\n";
         $counter++;
      }
      ########################
      #add optional parameters
      if($nobram){
        print SUBMAK "\t\@echo \"   RAM DISTRIBUTED\" >> $projrep\n";
      }
      ########################
      print SUBMAK "\t\@echo \"-----------------------------------------";
      print SUBMAK "-----------------------------\" >> $projrep\n";
      $counter = 0;
      #set line for .in.xst
      print SUBMAK "\t\@echo \"-generics {";
      foreach(@fieldparam){
         print SUBMAK "@fieldparam[$counter]=@fieldvalue[$counter]";
         $counter++;
         unless ($counter==scalar(@fieldparam)){
            print SUBMAK " ";
         }
      }
      print SUBMAK "}\" >> $project.in.xst\n";
      ########################
      #add optional parameters
      if($nobram){
        print SUBMAK "\t\@echo \"-ram_style distributed\" >> $project.in.xst\n";
        print SUBMAK "\t\@echo \"-rom_style distributed\" >> $project.in.xst\n";
      }
      ########################
      #set line for execute xilproject
      print SUBMAK "\txil_project.pl --no-standalone --make $xilprjfile\n";
    }
  }
}
close(SUBMAK);
close (GENLIST);
system("make -f $submak");

##############################################################################
sub ParseCommandLine                       # Original code from xil_project.pl
{
 GetOptions("project=s"    => \$project,
            "input=s"      => \$genlist,
            "no-bram"      => \$nobram,
            "force"        => \$force,
            "help|?"       => \$help) or ShowHelp();
 ShowHelp() if $help;
 unless ($project)
   {
    print "You must specify a project name\n";
    ShowHelp();
   }
 unless ($genlist)
   {
    print "You must specify a genlist file name\n";
    ShowHelp();
   }
 $projrep="$project.txt";
 $projinxst="$project.in.xst";
 $xilprjfile="$project.xilprj";
 $submak="$project.sub.mak";
 $prjfile="$project.prj";
}

##############################################################################
sub ShowHelp                               # Original code from xil_project.pl
{
 print "Usage: mide.pl --project=project_name --input=generic_list \n";
 print "\nAvailable options:\n";
 print "--no-bram      Use no BRAMS.\n";
 print "--force        Dependencies not included.\n";
 print "--help         Prints this text.\n\n";
 exit 1;
}


