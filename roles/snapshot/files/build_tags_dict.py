#!/usr/bin/env python

import sys
import ast

tags = sys.argv[1]
tags_dict = ast.literal_eval(tags)

dict_for_ec2_remote_facts = {}
for key, value in tags_dict.items():
    dict_for_ec2_remote_facts['tag:' + key] = value

print(dict_for_ec2_remote_facts)
