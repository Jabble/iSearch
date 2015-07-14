#!/bin/bash

index_name=.$1

for id in I$index_name.sn I$index_name.ss
do
	echo "Indexing $id..."	
	IndriBuildIndex ../Retrieval/Indexes/Param_Files/param-$id.xml ../Retrieval/smart-stopwords.xml > ../Retrieval/Indexes/Logs/indexing-$id.log
done

for id in I$index_name.nn I$index_name.ns
do
	echo "Indexing $id..."
	IndriBuildIndex ../Retrieval/Indexes/Param_Files/param-$id.xml > ../Retrieval/Indexes/Logs/indexing-$id.log
done

	
### Old code: 
# for index_name in .s001b000a
# do
# for id in I$index_name.sn I$index_name.ss
# do
#     echo "Indexing $id..."
#     IndriBuildIndex ../Retrieval/Indexes/Param_Files/param-$id.xml ../Retrieval/smart-stopwords.xml > ../Retrieval/Indexes/Logs/indexing-$id.log
# done
#
# for id in I$index_name.nn I$index_name.ns
# do
#     echo "Indexing $id..."
#     IndriBuildIndex ../Retrieval/Indexes/Param_Files/param-$id.xml > ../Retrieval/Indexes/Logs/indexing-$id.log
# done
# done

