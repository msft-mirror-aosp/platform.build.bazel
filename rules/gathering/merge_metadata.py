"""Generates a JSON file from merging package metadata formats."""

import argparse
import dataclasses
import json


@dataclasses.dataclass(frozen=True)
class Package:
  """Represents a dependency."""

  name: str
  version: str
  license_url: str
  license_name: str


def read_sbom_json(sbom_json_path: str) -> list[Package]:
  """Reads a SBOM JSON file and returns a list of packages."""
  with open(sbom_json_path, 'r') as f:
    json_data = json.load(f)

  spdx_id = json_data['SPDXID']
  relationships = json_data['relationships']
  for relationship in relationships:
    if (
        relationship['spdxElementId'] == spdx_id
        and relationship['relationshipType'] == 'DESCRIBES'
    ):
      root_element = relationship['relatedSpdxElement']
      break
  else:
    raise ValueError(f'No root element found for SPDX ID {spdx_id}')

  dependent_element_ids = []
  for relationship in relationships:
    if (
        relationship['spdxElementId'] == root_element
        and relationship['relationshipType'] == 'DEPENDS_ON'
    ):
      dependent_element_ids.append(relationship['relatedSpdxElement'])

  pkg_map = {pkg['SPDXID']: pkg for pkg in json_data['packages']}
  license_map = {
      license['licenseId']: license
      for license in json_data['hasExtractedLicensingInfos']
      if 'licenseId' in license
  }

  packages = []
  for dep_element_id in dependent_element_ids:
    pkg = pkg_map[dep_element_id]
    license_id = pkg['licenseDeclared']
    declared_license = license_map.get(license_id)
    if declared_license:
      license_url = declared_license.get('seeAlsos', [''])[0]
      license_name = declared_license['name']
    else:
      license_url = ''
      license_name = license_id
    packages.append(
        Package(
            name=pkg['name'],
            version=pkg['versionInfo'],
            license_url=license_url,
            license_name=license_name
        )
    )
  return packages


def read_third_party_libraries(
    third_party_libraries_path: str,
) -> list[Package]:
  """Reads a third party libraries JSON file and returns a list of packages."""
  with open(third_party_libraries_path, 'r') as f:
    json_data = json.load(f)
  packages = []
  for library in json_data:
    packages.append(
        Package(
            library['name'],
            library['version'],
            library['licenseUrl'],
            library['license'],
        )
    )
  return packages


def write_packages(packages: list[Package], output_path: str) -> None:
  """Writes a list of packages as a JSON file."""
  json_data = []
  for pkg in packages:
    json_data.append({
        'name': pkg.name,
        'version': pkg.version,
        'license_url': pkg.license_url,
        'license_name': pkg.license_name,
    })
  with open(output_path, 'w') as f:
    f.write(json.dumps(json_data, indent=2))


def main() -> None:
  parser = argparse.ArgumentParser()
  parser.add_argument(
      '--spdx_json', nargs='*', help='The SPDX JSON files to read'
  )
  parser.add_argument(
      '--third_party_libraries',
      nargs='*',
      help='The third party libraries to read',
  )
  parser.add_argument(
      '--output', help='A JSON file representing merged packages'
  )
  args = parser.parse_args()

  pkgs = []
  for spdx_json in args.spdx_json:
    pkgs.extend(read_sbom_json(spdx_json))
  for third_party_libraries in args.third_party_libraries:
    pkgs.extend(read_third_party_libraries(third_party_libraries))

  write_packages(pkgs, args.output)


if __name__ == '__main__':
  main()
