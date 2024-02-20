import os
import sys

print(sys.version)
print(os.getcwd())
print(os.environ)
print(sys.path)
print('Hello World')

import lib
lib.greet('you')

import requests
print(requests.get('http://example.com'))

# from smartcard.System import readers
# print(readers())