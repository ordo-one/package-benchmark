//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

extension String {
    func printAsHeader(addWhiteSpace:Bool = true) {
        let separator = String(repeating: "=", count: count)
        if addWhiteSpace {
            print("")
        }
        print(separator)
        print(self)
        print(separator)
        if addWhiteSpace {
            print("")
        }
    }
}
