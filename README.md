# qualia
Scripts for preparation and processing of exome data

## Procedure for copying data from encyrpted hard drives

1. Plug in hard drive
2. Enter passcode to unlock hard drive as described in [Apricorn manual](http://www.apricorn.com/pdf_product_manuals/Aegis_Padlock_Manual.pdf)
  * Enter passcode
  * Press unlock button
  * The *unlock* padlock icon will turn green if entered correctly
3. Run [transfer script](./bin/transfer_from_drive.py)

```
~/src/qualia/bin/transfer_from_drive.py --hard_drive CLA123456
```

  The transfer script will copy all data from from the hard drive using rsync to a predetermined location on a local computing cluster.
  
## Unpacking compressed files and verifying checksums

1. Log into computing cluster and move to copy destination
2. Run the [checksum verification script](./bin/unpack_and_check.py)

```
~/src/qualia/bin/unpack_and_check.py
```

Any failures will be reported to the terminal.  You can also check the logs for any files where the found checksum does not match the checksum reported in the manifest
  
```
grep FAILED checksum.log
```

This job can be run on the computing cluster like this:
```
qs -N "md5sum-check" -pe shm 8 "module load python/2.7; python /home/gmcinnes/src/ClaritasExomeAnalysis/bin/unpack_and_check.py"
```

## Running FastQC on the cluster
```
for x in `cat sample_list.txt | grep bam | grep -v bai` ; do qs -N "fastqc" "module load fastqc; fastqc -o fastqc/CLA00127 -f bam $x" ; done
```

#### Unpack the results
```
cd fastqc/CLA00127
unzip *.zip
```

#### Rename data files and link them to single directory
```
for x in `ls | grep -v zip | grep -v html` ; do s=`echo $x | cut -f1 -d_` ; echo $s ; mv $x\_fastqc/fastqc_data.txt $x\_fastqc/$x.fastqc_data.txt; done
mkdir reports
ln -s SHIP*_fastqc/SHIP*.fastqc_data.txt reports
```

## Run fastqc analysis script
```
Rscript ~/src/qualia/bin/fastqc_analysis.R --drive_id='CLA00127' --path='/srv/gsfs0/projects/mvp/Claritas_ion_torrent_exomes/data/fastqc/CLA00127/reports'
```
