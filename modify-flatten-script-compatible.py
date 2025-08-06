#!/usr/bin/env python3

import re

def replace_walrus(match):
    var_name = match.group(1)
    expr = match.group(2)
    return f"{var_name} = {expr}\n    if not {var_name}:"

with open('flatten-openalex-jsonl.py', 'r') as file:
    content = file.read()

# Replace walrus operators with compatible syntax
content = re.sub(r'if not \((\w+) := (.*?)\):', replace_walrus, content)

# Keep the main structure and imports
header = content.split('def flatten_authors')[0]

# Extract the works flattening function
works_function_match = re.search(r'def flatten_works\(\):.*?(?=def flatten_|if __name__)', content, re.DOTALL)
if works_function_match:
    works_function = works_function_match.group(0)
else:
    works_function = ""

# Create the new script with just works processing
new_content = header + works_function + '''

if __name__ == '__main__':
    flatten_works()
'''

with open('flatten-works-py37.py', 'w') as file:
    file.write(new_content)

print("Modified script created as flatten-works-py37.py")
