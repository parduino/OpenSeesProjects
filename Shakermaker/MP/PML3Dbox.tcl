# ===================================================================== #
# 3D test model for the pml element modeling the plane strain field     #
# University of Washington, Department of Civil and Environmental Eng   #
# Geotechnical Eng Group, A. Pakzad, P. Arduino - Jun 2023              #
# Basic units are m, Ton(metric), s										#
# ===================================================================== #
set pid [getPID]
set np  [getNP]

# get DOPML from command line
if {$argc >0} {
    set DOPML [lindex $argv 0]
    if {$argc >1} {
        set ignore [lindex $argv 1]
    } else {
        set ignore "NO"
    }
} else {
    set DOPML "NO"
    set ignore "NO"
}

if {$pid==0} {
    puts "pid: $pid"
    puts "np: $np"
    puts "DOPML: $DOPML"
    puts "ignore: $ignore"
}

# ============================================================================
# define geometry and meshing parameters
# ============================================================================
wipe 
set lx           70.0;
set ly           70.0;
set lz           30.0;
set dy           5.0;
set dx           5.0;
set dz           5.0;
set nx           [expr $lx/$dx ]
set ny           [expr $ly/$dy ]
set nz           [expr $lz/$dz ]
set pmlthickness 20.0
set regcores     2
set pmlcores     2

barrier
# ============================================================================
#  run the mesh generator
# ============================================================================
if {$pid==0} {
    # find that if python is exisiting in the system
    set pythonexec "python3"
    if { [catch {exec python3 -V} python3_version] } {
        if { [catch {exec python -V} python_version] } {
            puts "Python is not installed in the system"
            exit
        } else {
            set pythonexec "python"
        }
    }
    puts "pythonexec: $pythonexec"


    # run the 3D_2DfieldMESH.py to generate the mesh and check if it is finished using catch
    
    # passing the arguments to the python script: lx ly lz dx dy dz pmlthickness
    if {$ignore == "NO"} {
        catch {eval "exec $pythonexec PML3DboxMESH.py $regcores $pmlcores $lx $ly $lz $dx $dy $dz $pmlthickness"} result 
        puts "result: $result"
    }

}
# wait for the mesh generator to finish 
barrier

# ============================================================================
# bulding regular elements
# ============================================================================
set E           0.2e11                 ;# --- Young's modulus
set nu          0.25                   ;# --- Poisson's Ratio
set rho         2000.0                 ;# --- Density
set Vs           [expr {sqrt($E / (2.0 * (1.0 + $nu) * $rho))}]
puts "Vs: $Vs"

if {$pid < $regcores} {
    # create nodes and elements
    model BasicBuilder -ndm 3 -ndf 3
    set materialTag 1;
    
    nDMaterial ElasticIsotropic 1 $E $nu $rho;
    eval "source nodes$pid.tcl"
    eval "source elements$pid.tcl"
}
# if {$DOPML == "YES" && $pid < $regcores} {
#     model BasicBuilder -ndm 3 -ndf 9;
#     eval "source boundary$pid.tcl"
# }
barrier
# ============================================================================
# bulding PML layer
# ============================================================================
#create PML nodes and elements
if {$DOPML == "YES" && $pid >= $regcores} {

    model BasicBuilder -ndm 3 -ndf 9;
    # create PML material
    set gamma           0.5                   ;# --- Coefficient gamma, newmark gamma = 0.5
    set beta            0.25                  ;# --- Coefficient beta,  newmark beta  = 0.25
    set eta             [expr 1.0/12.]        ;# --- Coefficient eta,   newmark eta   = 1/12 
    set E               $E                    ;# --- Young's modulus
    set nu              $nu                   ;# --- Poisson's Ratio
    set rho             $rho                  ;# --- Density
    set EleType         6                     ;# --- Element type, See line
    set PML_L           $pmlthickness         ;# --- Thickness of the PML
    set afp             2.0                   ;# --- Coefficient m, typically m = 2
    set PML_Rcoef       1.0e-8                ;# --- Coefficient R, typically R = 1e-8
    set RD_half_width_x [expr $lx/2.]         ;# --- Halfwidth of the regular domain in
    set RD_half_width_y [expr $ly/2.]         ;# --- Halfwidth of the regular domain in
    set RD_depth        [expr $lz/1.]         ;# --- Depth of the regular domain
    set Damp_alpha      0.0                   ;# --- Rayleigh damping coefficient alpha
    set Damp_beta       0.0                   ;# --- Rayleigh damping coefficient beta 
    set PMLMaterial "$eta $beta $gamma $E $nu $rho $EleType $PML_L $afp $PML_Rcoef $RD_half_width_x $RD_half_width_y $RD_depth $Damp_alpha $Damp_beta"
    # set PMLMaterial "$E $nu $rho $EleType $PML_L $afp $PML_Rcoef $RD_half_width_x $RD_half_width_y $RD_depth $Damp_alpha $Damp_beta"

    puts "PMLMaterial: $PMLMaterial"
    eval "source pmlnodes$pid.tcl"
    eval "source pmlelements$pid.tcl"

    # tie pml nodes to the regular nodes
    model BasicBuilder -ndm 3 -ndf 3;
    eval "source boundary$pid.tcl"
    
}

barrier

# ============================================================================
# creating fixities
# ============================================================================
if {$DOPML == "YES"} {
    if {$pid >=$regcores} {
        fixX [expr -$lx/2. - $pmlthickness] 1 1 1 0 0 0 0 0 0;
        fixX [expr  $lx/2. + $pmlthickness] 1 1 1 0 0 0 0 0 0;
        fixY [expr -$ly/2. - $pmlthickness] 1 1 1 0 0 0 0 0 0;
        fixY [expr  $ly/2. + $pmlthickness] 1 1 1 0 0 0 0 0 0;
        fixZ [expr -$lz/1. - $pmlthickness] 1 1 1 0 0 0 0 0 0;
    }
} else {
    if {$pid < $regcores} {
        fixX [expr -$lx/2.] 1 1 1;
        fixX [expr  $lx/2.] 1 1 1;
        fixY [expr -$ly/2.] 1 1 1;
        fixY [expr  $ly/2.] 1 1 1;
        fixZ [expr -$lz/1.] 1 1 1;
    }
}

# ============================================================================
# loading 
# ============================================================================
set dT 0.01
# timeSeries Path 1 -dt 0.001 -filePath force.dat -factor -1.0
source load.tcl
if {$pid < $regcores} {
    pattern H5DRM 2 "test.h5drm" 1.0 1000.0 0.001 1   0.0 1.0 0.0 1.0 -0.0 0.0 0.0 0.0 -1.0   0.0 0.0 0.0
}
# pattern Plain 1 1 {
#     source load.tcl
# }

setTime 8.0
# ============================================================================
# recorders
# ============================================================================

eval "recorder Node -file NodeDisp$pid.out -time -node $recordList  -dof 1 2 3 disp"
eval "recorder Node -file NodeAccl$pid.out -time -node $recordList  -dof 1 2 3 accel"
eval "recorder Node -file NodeVelo$pid.out -time -node $recordList  -dof 1 2 3 vel"

# ============================================================================
# Analysis 
# ============================================================================
# Analysis 
# print "PML3D_1DExample2MP1_pid$pid.info" 
domainChange
if {$DOPML == "YES"} {
    constraints      Plain
    numberer         ParallelRCM
    system           Mumps -ICNTL14 200
    test             NormDispIncr 1e-4 10 2
    algorithm        Linear -factorOnce 
    # algorithm        ModifiedNewton -factoronce
    # algorithm        ModifiedNewton
    # algorithm        Newton 
    integrator       Newmark 0.5 0.25
    # integrator       HHT 1.0
    analysis         Transient
    set startTime [clock milliseconds]
    for {set i 0} { $i < 1200 } { incr i 1 } {
        if {$pid ==0 } {puts "Time step: $i";}
        set OK [analyze 1 $dT]
        if {$OK < 0} {
            algorithm       ModifiedNewton
            set set OK [analyze 1 $dT]
            if {$OK >=0 } {algorithm        ModifiedNewton -factoronce}
        }
        if {$OK < 0} {
            algorithm       Newton
            set set OK [analyze 1 $dT]
            if {$OK >=0 } {algorithm        ModifiedNewton -factoronce}
        }
        

    }
    set endTime [clock milliseconds]
    set elapsedTime [expr {$endTime - $startTime}]
    puts "Elapsed time: [expr $elapsedTime/1000.] seconds in $pid"
} else {
    constraints      Plain
    numberer         ParallelRCM
    system           Mumps -ICNTL14 200
    test             NormDispIncr 1e-3 3 2
    algorithm        Linear -factorOnce 
    # algorithm        ModifiedNewton 
    integrator       Newmark 0.5 0.25
    analysis         Transient

    set startTime [clock milliseconds]
    for {set i 0} { $i < 1200 } { incr i 1 } {
        if {$pid ==0 } {puts "Time step: $i";}
        analyze 1 $dT
    }
    set endTime [clock milliseconds]
    set elapsedTime [expr {$endTime - $startTime}]
    puts "Elapsed time: [expr $elapsedTime/1000.] seconds in $pid"

    
}
wipeAnalysis
remove recorders
remove loadPattern 2