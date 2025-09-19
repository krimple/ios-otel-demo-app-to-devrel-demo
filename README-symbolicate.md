# To symbolicate an iOS build

See (this doc)[bd6d37e5-79d3-4dff-8deb-ee70e995a696] on how to do it, TL;DR:

in XCode itself:
1. make sure you select a target for your XCode build
2. build for that target
3. product -> archive - here you need an Apple developer license and an accepted agreement
4. check the name of the archive file
5. run the script identify-dSYM.sh <archive name> - it will point to the dSYM directory to copy

Note - you'll edit this script and modify how you process the file and copy it to file storage

