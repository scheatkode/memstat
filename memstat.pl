#!/usr/bin/env perl

 ###########################################################################//*!
 # @mainpage MemStat                                                          #
 # @file     memstat.pl                                                       #
 # @author   alice <chaoticmurlock@gmail.com>                                 #
 # @version  1.0                                                              #
 # @date     28/11/2015                                                       #
 #                                                                            #
 # @brief    FreeBSD memory information.                                      #
 #                                                                            #
 # @section  LICENSE                                                          #
 # Copyright (c) 2015, Alice                                                  #
 # All rights reserved.                                                       #
 #                                                                            #
 # Redistribution and use in source and binary forms, with or without         #
 # modification, are permitted provided that the following conditions         #
 # are met:                                                                   #
 # 1. Redistributions of source code must retain the above copyright          #
 #    notice, this list of conditions and the following disclaimer.           #
 # 2. Redistributions in binary form must reproduce the above copyright       #
 #    notice, this list of conditions and the following disclaimer in the     #
 #    documentation and/or other materials provided with the distribution.    #
 # 3. Neither the name of the University nor the names of its contributors    #
 #    may be used to endorse or promote products derived from this software   #
 #    without specific prior written permission.                              #
 #                                                                            #
 # THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND    #
 # ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE      #
 # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE #
 # ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE   #
 # FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL #
 # DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS    #
 # OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)      #
 # HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT #
 # LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY  #
 # OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF     #
 # SUCH DAMAGE.                                                               #
 #//##########################################################################*/


# Query the system through the generic sysctl(8) interface
# (this does not require special priviledges)

my %sctl = {};
my $sout = `/sbin/sysctl -a`;

foreach my $line (split(/\n/, $sout)) {
    $sctl{$1} = $2 if ($line =~ /^([^:]+):[[:space:]]+(.+)[[:space:]]*$/s);
}


# Round the physical memory size to the next power of two which is reasonable
# for memory cards. We do this by first determining the guessed memory card
# size under the assumption that usual computer hardware has an average of a
# maximally eight memory cards installed and those are usually of equal size.

sub mem_rounded {
    my ($mem_size) = @_;
    my $chip_size  = 1;
    my $chip_guess = ($mem_size / 8) - 1;
    while ($chip_guess != 0) {
        $chip_guess >>= 1;
        $chip_size  <<= 1;
    }
    my $mem_round = (int($mem_size / $chip_size) + 1) * $chip_size;
    return $mem_round;
}


# Determine the individual known information
# NOTICE: forget hw.usermem, it is just (hw.physmem - vm.stats.vm.v_wire_count).
# NOTICE: forget vm.stats.misc.zero_page_count, it is just the subset of
#         vm.stats.vm.v_free_count which is already pre-zeroed.

my $m_hw = &mem_rounded($sctl{"hw.physmem"});
my $m_ph = $sctl{"hw.physmem"};
my $m_all= $sctl{"vm.stats.vm.v_page_count"}     * $sctl{"hw.pagesize"};
my $m_wi = $sctl{"vm.stats.vm.v_wire_count"}     * $sctl{"hw.pagesize"};
my $m_ac = $sctl{"vm.stats.vm.v_active_count"}   * $sctl{"hw.pagesize"};
my $m_in = $sctl{"vm.stats.vm.v_inactive_count"} * $sctl{"hw.pagesize"};
my $m_ca = $sctl{"vm.stats.vm.v_cache_count"}    * $sctl{"hw.pagesize"};
my $m_fr = $sctl{"vm.stats.vm.v_free_count"}     * $sctl{"hw.pagesize"};


# Determine the individual unknown information

my $m_gv = $m_all - ($m_wi + $m_ac + $m_in + $m_ca + $m_fr);
my $m_gs = $m_ph  - $m_all;
my $m_gh = $m_hw  - $m_ph;


# Determine logical summary information

my $m_to = $m_hw;
my $m_av = $m_in + $m_ca + $m_fr;
my $m_us = $m_to - $m_av;


# Information annotations

my %i = (
    "m_w"   => 'Wired:      disabled for paging out',
    "m_a"   => 'Active:     recently referenced',
    "m_i"   => 'Inactive:   recently not referenced',
    "m_c"   => 'Cached:     almost avail. for alloc.',
    "m_f"   => 'Free:       fully available for alloc',
    "m_gv"  => 'Memory gap: UNKNOWN',
    "m_all" => 'Total real memory managed',
    "m_gs"  => 'Memory gap: Kernel?!',
    "m_p"   => 'Total real memory available',
    "m_gh"  => 'Memory gap: Segment Mappings?!',
    "m_hw"  => 'Total real memory installed',
    "m_u"   => 'Logically used memory',
    "m_av"  => 'Logically available memory',
    "m_t"   => 'Logically total memory',
);

my @f = (
    "%8s : %12d (%7dMB) [%3d%%] %s\n",
    "%8s : %12d (%7dMB)        %s\n",
);


# Print results

printf("\nSYSTEM MEMORY INFORMATION:\n\n");
printf($f[0],"wire",     $m_wi, $m_wi / 1048576,($m_wi/$m_all)*100, $i{"m_w"});
printf($f[0],"active",   $m_ac, $m_ac / 1048576,($m_ac/$m_all)*100, $i{"m_a"});
printf($f[0],"inactive", $m_in, $m_in / 1048576,($m_in/$m_all)*100, $i{"m_i"});
printf($f[0],"cache",    $m_ca, $m_ca / 1048576,($m_ca/$m_all)*100, $i{"m_c"});
printf($f[0],"free",     $m_fr, $m_fr / 1048576,($m_fr/$m_all)*100, $i{"m_f"});
printf($f[0],"gap_vm",   $m_gv, $m_gv / 1048576,($m_gv/$m_all)*100, $i{"m_gv"});
print "---------- ------------ ----------- ------\n";
printf($f[0],"all",      $m_all,$m_all/ 1048576, 100, $i{"m_all"});
printf($f[1],"gap_sys",  $m_gs, $m_gs / 1048576, $i{"m_gs"});
print "---------- ------------ -----------\n";
printf($f[1],"phys",     $m_ph, $m_ph / 1048576, $i{"m_p"});
printf($f[1],"gap_hw",   $m_gh, $m_gh / 1048576, $i{"m_gh"});
print  "--------- ------------ -----------\n";
printf($f[1],"hw",       $m_hw, $m_hw / 1048576, $i{"m_hw"});     

printf("\nSYSTEM MEMORY SUMMARY:\n\n");
printf($f[0],"used",  $m_us, $m_us /1048576, ($m_us / $m_to) * 100, $i{"m_u"});
printf($f[0],"avail", $m_av, $m_av /1048576, ($m_av / $m_to) * 100, $i{"m_av"});
print "---------- ------------ ----------- ------\n";
printf($f[0],"total", $m_to, $m_to / 1048576, 100, $i{"m_t"});
print "\n";

