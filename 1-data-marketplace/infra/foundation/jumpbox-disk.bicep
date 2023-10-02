param jumpboxDiskName string

resource jumpboxOsCreatedDisk 'Microsoft.Compute/disks@2022-07-02' existing = {
  name: jumpboxDiskName
}

output creationData object = jumpboxOsCreatedDisk.properties.creationData
