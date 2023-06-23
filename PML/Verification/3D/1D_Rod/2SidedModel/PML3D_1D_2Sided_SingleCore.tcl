# ===================================================================== #
# 3D test model for the pml element modeling the 1D Rod has PML element #
# on both sides (This model is for single core)                         #
# University of Washington, Department of Civil and Environmental Eng   #
# Geotechnical Eng Group, A. Pakzad, P. Arduino - Jun 2023              #
# Basic units are m, Ton(metric), s										#
# ===================================================================== #

# get DOPML from command line
if {$argc > 0} {
    set DOPML [lindex $argv 0]
} else {
    set DOPML "NO"
}


# building nodes and elements
wipe 
model BasicBuilder -ndm 3 -ndf 3

set lx      50.;
set ly      2.0;
set lz      2.0;
set dy      1.0;
set dx      1.0;
set dz      1.0;
set nx      [expr $lx/$dx]
set ny      [expr $ly/$dy]
set nz      [expr $lz/$dz]

set xlist       {}
set ylist       {}
set zlist       {}
set DoflistEnd  {}
set DoflistHead {}
set Loadinglist {}

# creating a xlist from -lx/2 to lx/2
# creating a ylist from 0 to ly
# creating a zlist from 0 to lz
for {set i 0} { $i <= $nx } { incr i} {lappend xlist [expr $dx*$i - $lx/2.];}
for {set i 0} { $i <= $ny } { incr i} {lappend ylist [expr $dy*$i];}
for {set i 0} { $i <= $nz } { incr i} {lappend zlist [expr $dz*$i];}




set nodeTag    1;
set elementTag 1;


# creating nodes
set count 1;
foreach x $xlist {
    foreach y $ylist {
        foreach z $zlist {
            node  $nodeTag $x $y $z;
            fix $nodeTag 0 1 1
            puts "node $nodeTag $x $y $z;"
            # add nodes to the loading list if x ==0. 
            # using tolerance to avoid round off error
            set tol 0.0001;
            if {$x > -$tol && $x < $tol} {lappend Loadinglist [expr $nodeTag]};
            if {$count == 1} {lappend DoflistHead [expr $nodeTag];}
            if {$count == [expr $nx+1]} {lappend DoflistEnd [expr $nodeTag];}
            incr nodeTag;
        } 
    } 
    incr count;
}





# create material
set materialTag 1;
set E    2.08e8
set nu   0.3
set rho  2000.0
nDMaterial ElasticIsotropic $materialTag $E $nu $rho

# creating elements for 4 first nodes in x-y plane and then other in z direction (counterclock wise)
for {set x 0} {$x < $nx} {incr x 1} {
    for {set y 0} {$y < $ny} {incr y 1} {
        for {set z 0} {$z < $nz} {incr z 1} {
            set node1 [expr int($x    *($ny+1)*($nz+1) + $y    *($nz+1) + $z + 1)];
            set node2 [expr int(($x+1)*($ny+1)*($nz+1) + $y    *($nz+1) + $z + 1)];
            set node3 [expr int(($x+1)*($ny+1)*($nz+1) + ($y+1)*($nz+1) + $z + 1)];
            set node4 [expr int($x    *($ny+1)*($nz+1) + ($y+1)*($nz+1) + $z + 1)];
            set node5 [expr $node1 + 1];
            set node6 [expr $node2 + 1];
            set node7 [expr $node3 + 1];
            set node8 [expr $node4 + 1];
            puts "element stdBrick $elementTag $node1 $node2 $node3 $node4 $node5 $node6 $node7 $node8 $materialTag;"

            element stdBrick $elementTag $node1 $node2 $node3 $node4 $node5 $node6 $node7 $node8 $materialTag;
            incr elementTag;
        }
    }
}





#create PML nodes and elements
if {$DOPML == "YES"} {
    model BasicBuilder -ndm 3 -ndf 18;
    
    set dxPML 1.0;
    set dyPML $dy;
    set dzPML $dz;
    set lxPML 10.0;
    set lyPML $ly;
    set lzPML $lz;
    set nxPML [expr $lxPML/$dxPML ]
    set nyPML [expr $lyPML/$dyPML ]
    set nzPML [expr $lzPML/$dzPML ]

    set PMLxlist {}
    set PMLylist {}
    set PMLzlist {}
    set PMLDoflist {}
    

    for {set i 0} {$i<=$nxPML} {incr i} {lappend PMLxlist [expr $dxPML*$i + $lx/2.];}
    for {set i 0} {$i<=$nyPML} {incr i} {lappend PMLylist [expr $dyPML*$i];}
    for {set i 0} {$i<=$nzPML} {incr i} {lappend PMLzlist [expr $dzPML*$i];}

    # create PML material
    set E               $E                    ;# --- Young's modulus
    set nu              $nu                   ;# --- Poisson's Ratio
    set rho             $rho                  ;# --- Density
    set EleType         6                     ;# --- Element type, See line
    set PML_L           $lxPML                ;# --- Thickness of the PML
    set afp             2.0                   ;# --- Coefficient m, typically m = 2
    set PML_Rcoef       1.0e-8                ;# --- Coefficient R, typically R = 1e-8
    set RD_half_width_x [expr $lx/2.]         ;# --- Halfwidth of the regular domain in
    set RD_half_width_y [expr $lx/2.]         ;# --- Halfwidth of the regular domain in
    set RD_depth        [expr $lx/2.]         ;# --- Depth of the regular domain
    set Damp_alpha      0.0                   ;# --- Rayleigh damping coefficient alpha
    set Damp_beta       0.0                   ;# --- Rayleigh damping coefficient beta 
    set PMLMaterial "$E $nu $rho $EleType $PML_L $afp $PML_Rcoef $RD_half_width_x $RD_half_width_y $RD_depth $Damp_alpha $Damp_beta"
    puts "PMLMaterial: $PMLMaterial"


    # create nodes for the end side of the PML
    set count 1;
    foreach x $PMLxlist {
        foreach y $PMLylist {
            foreach z $PMLzlist {
                node  $nodeTag $x $y $z;
                fix $nodeTag 0 1 1 0 0 0 0 0 0 0 1 1 0 0 0 0 0 0;
                if {$count == 1} {lappend PMLDoflist [expr $nodeTag];}
                puts "node $nodeTag $x $y $z;"
                incr nodeTag;
            } 
        } 
        incr count;
    }


    # creating elements for the end side of the PML
    for {set x 0} { $x < $nxPML } { incr x 1 } {
        for {set y 0} { $y < $nyPML } { incr y 1 } {
            for {set z 0} { $z < $nzPML } { incr z 1 } {
                set node1 [expr int($x    *($ny+1)*($nz+1) + $y    *($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1))];
                set node2 [expr int(($x+1)*($ny+1)*($nz+1) + $y    *($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1))];
                set node3 [expr int(($x+1)*($ny+1)*($nz+1) + ($y+1)*($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1))];
                set node4 [expr int($x    *($ny+1)*($nz+1) + ($y+1)*($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1))];
                set node5 [expr $node1 + 1];
                set node6 [expr $node2 + 1];
                set node7 [expr $node3 + 1];
                set node8 [expr $node4 + 1];
                eval "element PML $elementTag $node1 $node2 $node3 $node4 $node5 $node6 $node7 $node8 $PMLMaterial";
                incr elementTag;
            }
        }
    }


    # tie PML nodes to the main nodes
    for {set i 0} { $i < [llength $PMLDoflist] } { incr i 1 } {
        equalDOF [lindex $DoflistEnd $i] [lindex $PMLDoflist $i] 1;
        puts "equalDOF [lindex $DoflistEnd $i] [lindex $PMLDoflist $i] 1;"
    }



    
    # create nodes for the head side of the PML
    set PMLxlist {}
    for {set i 0} {$i<=$nxPML} {incr i} {lappend PMLxlist [expr $dxPML*$i - $lx/2. - $nxPML*$dxPML];}
    set count 1;
    set PMLDoflist {}
    foreach x $PMLxlist {
        foreach y $PMLylist {
            foreach z $PMLzlist {
                node  $nodeTag $x $y $z;
                fix $nodeTag 0 1 1 0 0 0 0 0 0 0 1 1 0 0 0 0 0 0;
                if {$count == $nxPML+1} {lappend PMLDoflist [expr $nodeTag];}
                puts "node $nodeTag $x $y $z;"
                incr nodeTag;
            } 
        } 
        incr count;
    }

    # creating elements for the head side of the PML 
    for {set x 0 } {$x < $nxPML} {incr x} {
        for {set y 0} {$y < $nyPML} {incr y} {
            for  {set z 0} {$z < $nzPML} {incr z} {
                set node1 [expr int($x    *($ny+1)*($nz+1) + $y    *($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1) + ($nxPML+1)*($nyPML+1)*($nzPML+1))];
                set node2 [expr int(($x+1)*($ny+1)*($nz+1) + $y    *($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1) + ($nxPML+1)*($nyPML+1)*($nzPML+1))];
                set node3 [expr int(($x+1)*($ny+1)*($nz+1) + ($y+1)*($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1) + ($nxPML+1)*($nyPML+1)*($nzPML+1))];
                set node4 [expr int(($x)  *($ny+1)*($nz+1) + ($y+1)*($nz+1) + $z + 1 + ($nx+1)*($ny+1)*($nz+1) + ($nxPML+1)*($nyPML+1)*($nzPML+1))];
                set node5 [expr $node1 + 1];
                set node6 [expr $node2 + 1];
                set node7 [expr $node3 + 1];
                set node8 [expr $node4 + 1];
                eval "element PML $elementTag $node1 $node2 $node3 $node4 $node5 $node6 $node7 $node8 $PMLMaterial";
                incr elementTag;
            }   
        }
    }

    # tie PML nodes to the main nodes
    for {set i 0} { $i < [llength $PMLDoflist] } { incr i 1 } {
        equalDOF [lindex $DoflistHead $i] [lindex $PMLDoflist $i] 1;
        puts "equalDOF [lindex $DoflistHead $i] [lindex $PMLDoflist $i] 1;"
    }
    
}


# creating fixities
if {$DOPML == "YES"} {
    fixX [expr $lxPML  + $lx/2.] 1 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0;
    fixX [expr -$lxPML - $lx/2.] 1 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0;
} else {
    fixX [expr $lx/2.]  1 0 0;
    fixX [expr -$lx/2.] 1 0 0;
}


# loading 
set dT 0.001
timeSeries Path 1 -dt 0.001 -filePath force.dat -factor 1.0
pattern Plain 1 1 {
    foreach node $Loadinglist {
        load $node 1.0 0.0 0.0
    }
}




# recorders
eval "recorder Node -file NodeDispHead.out  -time -node $DoflistHead  -dof 1 disp"
eval "recorder Node -file NodeDispEnd.out   -time -node $DoflistEnd    -dof 1 disp"
eval "recorder Node -file NodeDispCent.out  -time -node $Loadinglist    -dof 1 disp"



print "PML3D_1DExample2.info" 

# Analysis 
constraints   Plain
numberer      RCM
integrator    Newmark 0.5 0.25
system        BandGEN
test          NormDispIncr 1.0e-6 10 1
algorithm     Linear -factorOnce
analysis      Transient


for {set i 0} { $i < 1000 } { incr i 1 } {
    puts "Time step: $i"
    analyze 1 $dT
}







