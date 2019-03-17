function Hash-Me {
    param(
        $HashName,
        $InputObject
    )
  
    $hash = @{"$HashName"=$InputObject}
    $hashString = BetterJSON -InputObject $hash
    $hashString
  }
  