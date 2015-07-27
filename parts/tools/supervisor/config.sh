#!/bin/bash

# supervisor depends on python
PARTS="${PARTS} languages/python"

# install supervisor
packages="${packages} supervisor"
