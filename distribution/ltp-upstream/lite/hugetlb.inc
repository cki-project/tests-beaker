hugemmap01 hugemmap01 -s #nr_hpage#
hugemmap02 hugemmap02 -s #nr_hpage#
hugemmap04 hugemmap04 -s #nr_hpage#

hugemmap05 hugemmap05 -a #size#
hugemmap05_m hugemmap05 -m -a #size#
hugemmap05_s hugemmap05 -s -a #size#
hugemmap05_ms hugemmap05 -m -s -a #size#

hugemmap06 hugemmap06

hugeshmat01 hugeshmat01 -s #nr_hpage# -i 5
hugeshmat02 hugeshmat02 -s #nr_hpage# -i 5
hugeshmat03 hugeshmat03 -s #nr_hpage# -i 5
hugeshmat04 hugeshmat04 -i 5
hugeshmat05 hugeshmat05 -i 5

hugeshmctl01 hugeshmctl01 -s #nr_hpage# -i 5
hugeshmctl02 hugeshmctl02 -s #nr_hpage# -i 5
hugeshmctl03 hugeshmctl03 -s #nr_hpage# -i 5

hugeshmdt01 hugeshmdt01 -s #nr_hpage# -i 5

hugeshmget01 hugeshmget01 -s #nr_hpage# -i 10
hugeshmget02 hugeshmget02 -s #nr_hpage# -i 10
hugeshmget03 hugeshmget03 -s #nr_hpage# -i 10
hugeshmget05 hugeshmget05 -s #nr_hpage# -i 10
