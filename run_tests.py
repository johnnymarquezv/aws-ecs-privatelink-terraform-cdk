#!/usr/bin/env python3
"""
Test runner script for the microservice tests.
Run this from the project root directory.
"""
import subprocess
import sys
import os

def main():
    # Change to microservice directory
    microservice_dir = os.path.join(os.path.dirname(__file__), 'microservice')
    os.chdir(microservice_dir)
    
    # Run pytest
    result = subprocess.run([sys.executable, '-m', 'pytest', 'tests/', '-v'], 
                          capture_output=False)
    return result.returncode

if __name__ == '__main__':
    sys.exit(main())
