#!/usr/bin/env python3
#
# Copyright 2024, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from argparse import ArgumentParser as AP
from zipfile import ZipFile, ZIP_DEFLATED
import xml.etree.ElementTree as ET

def main():
    parser = AP(description='This tool takes an AAR and removes the <overlayable> resources')
    parser.add_argument('output')
    parser.add_argument('soong_aar')
    args = parser.parse_args()
    values_path = 'res/values/values.xml'
    print("input aar: " + args.soong_aar)

    with ZipFile(args.output, mode='w', compression=ZIP_DEFLATED) as outaar, ZipFile(args.soong_aar) as soongaar:
        # Parse XML, remove <overlayable>, and write to file
        try:
            file = soongaar.open(values_path)
            values = ET.parse(file)
            resources = values.getroot()
            overlayable = resources.find('overlayable')
            if overlayable is not None:
                resources.remove(overlayable)
            data = ET.tostring(resources, encoding='unicode', xml_declaration=True)
            outaar.writestr(values_path, data)
        except KeyError:
            print("Could not find values.xml, skipping removal of overlayables")

        # copy all the other files
        for f in soongaar.namelist():
            if f != values_path:
                outaar.writestr(f, soongaar.read(f))

if __name__ == "__main__":
    main()
