# ClaritasExomeAnalysis
Scripts for preparation and processing of exome data from Claritas

## Procedure for copying data from encyrpted hard drives

1. Plug in hard drive
2. Enter passcode to unlock hard drive as described in [Apricorn manual](http://www.apricorn.com/pdf_product_manuals/Aegis_Padlock_Manual.pdf)
  * Enter passcode
  * Press unlock button
  * The *unlock* padlock icon will turn green if entered correctly
3. Run [transfer script](./bin/transfer_from_drive.py)

```
~/src/ClaritasExomeSequencing/bin/transfer_from_drive --hard_drive CLA123456
```

  The transfer script will copy all data from from the hard drive using rsync to a predetermined location on a local computing cluster.
  
## Unpacking compressed files and verifying checksums

1. Log into computing cluster and move to copy destination
2. Run the [checksum verification script](./bin/unpack_and_check.py)

```
~/src/ClaritasExomeAnalysis/bin/unpack_and_check.py
```

Any failures will be reported to the terminal.  You can also check the logs for any files where the found checksum does not match the checksum reported in the manifest
  
```
grep FAILED checksum.log
```

This job can be run on the computing cluster like this:
```
qs -N "md5sum-check" -pe shm 8 "module load python/2.7; python /home/gmcinnes/src/ClaritasExomeAnalysis/bin/unpack_and_check.py"
```

## Upload to Google Cloud

Create bucket 
```
gsutil mb -c DRA -l US -p gbsc-gcp-project-mvp gs://gbsc-gcp-project-mvp-claritas
```

