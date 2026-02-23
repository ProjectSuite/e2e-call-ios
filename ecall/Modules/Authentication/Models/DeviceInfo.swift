import Foundation

struct DeviceInfo {
    /// Convert device identifier to commercial name
    static func getCommercialName(for identifier: String) -> String {
        for (prefix, handler) in deviceNameHandlers {
            if identifier.hasPrefix(String(prefix)) {
                return handler(identifier)
            }
        }
        return identifier
    }

    /// Get commercial name of current device
    static func getCurrentCommercialName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let currentIdentifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        return getCommercialName(for: currentIdentifier)
    }

    private static let deviceNameHandlers: [String.SubSequence: (String) -> String] = [
        "iPhone": getiPhoneName,
        "iPad": getiPadName,
        "iPod": getiPodName,
        "Watch": getAppleWatchName,
        "MacBook": getMacBookName,
        "iMac": getiMacName,
        "MacPro": getMacProName,
        "Macmini": getMacminiName,
        "Mac": getMacName,
        "AudioAcces": getHomePodName,
        "AppleTV": getAppleTVName,
        "RealityDe": getVisionProName
    ]

    // MARK: - iPhone Names
    private static func getiPhoneName(for identifier: String) -> String {
        return iPhoneNames[identifier] ?? identifier
    }

    private static let iPhoneNames: [String: String] = [
        "iPhone1,1": "iPhone",
        "iPhone1,2": "iPhone 3G",
        "iPhone2,1": "iPhone 3GS",
        "iPhone3,1": "iPhone 4",
        "iPhone3,2": "iPhone 4",
        "iPhone3,3": "iPhone 4",
        "iPhone4,1": "iPhone 4s",
        "iPhone5,1": "iPhone 5",
        "iPhone5,2": "iPhone 5",
        "iPhone5,3": "iPhone 5c",
        "iPhone5,4": "iPhone 5c",
        "iPhone6,1": "iPhone 5s",
        "iPhone6,2": "iPhone 5s",
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone7,2": "iPhone 6",
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1st generation)",
        "iPhone9,1": "iPhone 7",
        "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16",
        "iPhone17,2": "iPhone 16 Plus",
        "iPhone17,3": "iPhone 16 Pro",
        "iPhone17,4": "iPhone 16 Pro Max"
    ]

    // MARK: - iPad Names
    private static func getiPadName(for identifier: String) -> String {
        return iPadNames[identifier] ?? identifier
    }

    private static let iPadNames: [String: String] = [
        "iPad1,1": "iPad",
        "iPad1,2": "iPad 3G",
        "iPad2,1": "iPad 2",
        "iPad2,2": "iPad 2",
        "iPad2,3": "iPad 2",
        "iPad2,4": "iPad 2",
        "iPad2,5": "iPad mini",
        "iPad2,6": "iPad mini",
        "iPad2,7": "iPad mini",
        "iPad3,1": "iPad (3rd generation)",
        "iPad3,2": "iPad (3rd generation)",
        "iPad3,3": "iPad (3rd generation)",
        "iPad3,4": "iPad (4th generation)",
        "iPad3,5": "iPad (4th generation)",
        "iPad3,6": "iPad (4th generation)",
        "iPad3,7": "iPad Air",
        "iPad3,8": "iPad Air",
        "iPad3,9": "iPad Air",
        "iPad4,1": "iPad Air 2",
        "iPad4,2": "iPad Air 2",
        "iPad4,3": "iPad Air 2",
        "iPad4,4": "iPad mini 2",
        "iPad4,5": "iPad mini 2",
        "iPad4,6": "iPad mini 2",
        "iPad4,7": "iPad mini 3",
        "iPad4,8": "iPad mini 3",
        "iPad4,9": "iPad mini 3",
        "iPad5,1": "iPad mini 4",
        "iPad5,2": "iPad mini 4",
        "iPad5,3": "iPad Air (3rd generation)",
        "iPad5,4": "iPad Air (3rd generation)",
        "iPad6,3": "iPad Pro (9.7-inch)",
        "iPad6,4": "iPad Pro (9.7-inch)",
        "iPad6,7": "iPad Pro (12.9-inch)",
        "iPad6,8": "iPad Pro (12.9-inch)",
        "iPad6,11": "iPad (5th generation)",
        "iPad6,12": "iPad (5th generation)",
        "iPad7,1": "iPad Pro (12.9-inch, 2nd generation)",
        "iPad7,2": "iPad Pro (12.9-inch, 2nd generation)",
        "iPad7,3": "iPad Pro (10.5-inch)",
        "iPad7,4": "iPad Pro (10.5-inch)",
        "iPad7,5": "iPad (6th generation)",
        "iPad7,6": "iPad (6th generation)",
        "iPad7,11": "iPad (7th generation)",
        "iPad7,12": "iPad (7th generation)",
        "iPad8,1": "iPad Pro (11-inch)",
        "iPad8,2": "iPad Pro (11-inch)",
        "iPad8,3": "iPad Pro (11-inch)",
        "iPad8,4": "iPad Pro (11-inch)",
        "iPad8,5": "iPad Pro (12.9-inch, 3rd generation)",
        "iPad8,6": "iPad Pro (12.9-inch, 3rd generation)",
        "iPad8,7": "iPad Pro (12.9-inch, 3rd generation)",
        "iPad8,8": "iPad Pro (12.9-inch, 3rd generation)",
        "iPad8,9": "iPad Pro (11-inch, 2nd generation)",
        "iPad8,10": "iPad Pro (11-inch, 2nd generation)",
        "iPad8,11": "iPad Pro (11-inch, 2nd generation)",
        "iPad8,12": "iPad Pro (11-inch, 2nd generation)",
        "iPad8,13": "iPad Pro (12.9-inch, 4th generation)",
        "iPad8,14": "iPad Pro (12.9-inch, 4th generation)",
        "iPad8,15": "iPad Pro (12.9-inch, 4th generation)",
        "iPad8,16": "iPad Pro (12.9-inch, 4th generation)",
        "iPad11,1": "iPad mini (5th generation)",
        "iPad11,2": "iPad mini (5th generation)",
        "iPad11,3": "iPad Air (4th generation)",
        "iPad11,4": "iPad Air (4th generation)",
        "iPad11,6": "iPad (8th generation)",
        "iPad11,7": "iPad (8th generation)",
        "iPad12,1": "iPad (9th generation)",
        "iPad12,2": "iPad (9th generation)",
        "iPad13,1": "iPad Air (5th generation)",
        "iPad13,2": "iPad Air (5th generation)",
        "iPad13,4": "iPad Pro (11-inch, 3rd generation)",
        "iPad13,5": "iPad Pro (11-inch, 3rd generation)",
        "iPad13,6": "iPad Pro (11-inch, 3rd generation)",
        "iPad13,7": "iPad Pro (11-inch, 3rd generation)",
        "iPad13,8": "iPad Pro (12.9-inch, 5th generation)",
        "iPad13,9": "iPad Pro (12.9-inch, 5th generation)",
        "iPad13,10": "iPad Pro (12.9-inch, 5th generation)",
        "iPad13,11": "iPad Pro (12.9-inch, 5th generation)",
        "iPad13,16": "iPad Air (6th generation)",
        "iPad13,17": "iPad Air (6th generation)",
        "iPad13,18": "iPad (10th generation)",
        "iPad13,19": "iPad (10th generation)",
        "iPad14,1": "iPad mini (6th generation)",
        "iPad14,2": "iPad mini (6th generation)",
        "iPad14,3": "iPad mini (7th generation)",
        "iPad14,4": "iPad mini (7th generation)",
        "iPad14,5": "iPad (11th generation)",
        "iPad14,6": "iPad (11th generation)",
        "iPad14,7": "iPad Pro (11-inch, 4th generation)",
        "iPad14,8": "iPad Pro (11-inch, 4th generation)",
        "iPad14,9": "iPad Pro (12.9-inch, 6th generation)",
        "iPad14,10": "iPad Pro (12.9-inch, 6th generation)",
        "iPad15,1": "iPad Air (7th generation)",
        "iPad15,2": "iPad Air (7th generation)",
        "iPad15,3": "iPad (12th generation)",
        "iPad15,4": "iPad (12th generation)",
        "iPad15,5": "iPad Pro (11-inch, 5th generation)",
        "iPad15,6": "iPad Pro (11-inch, 5th generation)",
        "iPad15,7": "iPad Pro (12.9-inch, 7th generation)",
        "iPad15,8": "iPad Pro (12.9-inch, 7th generation)"
    ]

    // MARK: - iPod Names
    private static func getiPodName(for identifier: String) -> String {
        switch identifier {
        case "iPod1,1": return "iPod touch"
        case "iPod2,1": return "iPod touch (2nd generation)"
        case "iPod3,1": return "iPod touch (3rd generation)"
        case "iPod4,1": return "iPod touch (4th generation)"
        case "iPod5,1": return "iPod touch (5th generation)"
        case "iPod7,1": return "iPod touch (6th generation)"
        case "iPod9,1": return "iPod touch (7th generation)"
        default: return identifier
        }
    }

    // MARK: - Apple Watch Names
    private static func getAppleWatchName(for identifier: String) -> String {
        return appleWatchNames[identifier] ?? identifier
    }

    private static let appleWatchNames: [String: String] = [
        "Watch1,1": "Apple Watch (1st generation)",
        "Watch1,2": "Apple Watch (1st generation)",
        "Watch2,6": "Apple Watch Series 1",
        "Watch2,7": "Apple Watch Series 1",
        "Watch2,3": "Apple Watch Series 2",
        "Watch2,4": "Apple Watch Series 2",
        "Watch3,1": "Apple Watch Series 3",
        "Watch3,2": "Apple Watch Series 3",
        "Watch3,3": "Apple Watch Series 3",
        "Watch3,4": "Apple Watch Series 3",
        "Watch4,1": "Apple Watch Series 4",
        "Watch4,2": "Apple Watch Series 4",
        "Watch4,3": "Apple Watch Series 4",
        "Watch4,4": "Apple Watch Series 4",
        "Watch5,1": "Apple Watch Series 5",
        "Watch5,2": "Apple Watch Series 5",
        "Watch5,3": "Apple Watch Series 5",
        "Watch5,4": "Apple Watch Series 5",
        "Watch5,9": "Apple Watch SE",
        "Watch5,10": "Apple Watch SE",
        "Watch5,11": "Apple Watch SE",
        "Watch5,12": "Apple Watch SE",
        "Watch6,1": "Apple Watch Series 6",
        "Watch6,2": "Apple Watch Series 6",
        "Watch6,3": "Apple Watch Series 6",
        "Watch6,4": "Apple Watch Series 6",
        "Watch6,6": "Apple Watch Series 7",
        "Watch6,7": "Apple Watch Series 7",
        "Watch6,8": "Apple Watch Series 7",
        "Watch6,9": "Apple Watch Series 7",
        "Watch6,10": "Apple Watch Series 8",
        "Watch6,11": "Apple Watch Series 8",
        "Watch6,12": "Apple Watch Series 8",
        "Watch6,13": "Apple Watch Series 8",
        "Watch6,14": "Apple Watch Series 9",
        "Watch6,15": "Apple Watch Series 9",
        "Watch6,16": "Apple Watch Series 9",
        "Watch6,17": "Apple Watch Series 9",
        "Watch6,18": "Apple Watch Ultra",
        "Watch6,19": "Apple Watch Ultra",
        "Watch6,20": "Apple Watch Ultra",
        "Watch6,21": "Apple Watch Ultra",
        "Watch6,22": "Apple Watch Ultra 2",
        "Watch6,23": "Apple Watch Ultra 2",
        "Watch6,24": "Apple Watch Ultra 2",
        "Watch6,25": "Apple Watch Ultra 2"
    ]

    // MARK: - MacBook Names
    private static func getMacBookName(for identifier: String) -> String {
        return macBookNames[identifier] ?? getMacBookAirName(for: identifier)
    }

    private static let macBookNames: [String: String] = [
        "MacBook1,1": "MacBook",
        "MacBook2,1": "MacBook (Late 2006)",
        "MacBook3,1": "MacBook (Late 2007)",
        "MacBook4,1": "MacBook (Early 2008)",
        "MacBook5,1": "MacBook (Late 2008)",
        "MacBook5,2": "MacBook (Early 2009)",
        "MacBook6,1": "MacBook (Late 2009)",
        "MacBook7,1": "MacBook (Mid 2010)",
        "MacBook8,1": "MacBook (Early 2015)",
        "MacBook9,1": "MacBook (Early 2016)",
        "MacBook10,1": "MacBook (Mid 2017)"
    ]

    private static func getMacBookAirName(for identifier: String) -> String {
        return macBookAirNames[identifier] ?? getMacBookProName(for: identifier)
    }

    private static let macBookAirNames: [String: String] = [
        "MacBookAir1,1": "MacBook Air",
        "MacBookAir2,1": "MacBook Air (Late 2008)",
        "MacBookAir3,1": "MacBook Air (Late 2010)",
        "MacBookAir3,2": "MacBook Air (Late 2010)",
        "MacBookAir4,1": "MacBook Air (Mid 2011)",
        "MacBookAir4,2": "MacBook Air (Mid 2011)",
        "MacBookAir5,1": "MacBook Air (Mid 2012)",
        "MacBookAir5,2": "MacBook Air (Mid 2012)",
        "MacBookAir6,1": "MacBook Air (Mid 2013)",
        "MacBookAir6,2": "MacBook Air (Mid 2013)",
        "MacBookAir7,1": "MacBook Air (Early 2014)",
        "MacBookAir7,2": "MacBook Air (Early 2014)",
        "MacBookAir8,1": "MacBook Air (Early 2015)",
        "MacBookAir8,2": "MacBook Air (Early 2015)",
        "MacBookAir9,1": "MacBook Air (Early 2016)",
        "MacBookAir9,2": "MacBook Air (Early 2016)",
        "MacBookAir10,1": "MacBook Air (Early 2017)",
        "MacBookAir10,2": "MacBook Air (Early 2017)",
        "MacBookAir11,1": "MacBook Air (Mid 2017)",
        "MacBookAir11,2": "MacBook Air (Mid 2017)",
        "MacBookAir12,1": "MacBook Air (Mid 2018)",
        "MacBookAir12,2": "MacBook Air (Mid 2018)",
        "MacBookAir13,1": "MacBook Air (Mid 2019)",
        "MacBookAir13,2": "MacBook Air (Mid 2019)",
        "MacBookAir14,1": "MacBook Air (Mid 2020)",
        "MacBookAir14,2": "MacBook Air (Mid 2020)",
        "MacBookAir15,1": "MacBook Air (Mid 2021)",
        "MacBookAir15,2": "MacBook Air (Mid 2021)",
        "MacBookAir15,3": "MacBook Air (Mid 2022)",
        "MacBookAir15,4": "MacBook Air (Mid 2022)",
        "MacBookAir15,5": "MacBook Air (Mid 2023)",
        "MacBookAir15,6": "MacBook Air (Mid 2023)",
        "MacBookAir16,1": "MacBook Air (Mid 2024)",
        "MacBookAir16,2": "MacBook Air (Mid 2024)"
    ]

    private static func getMacBookProName(for identifier: String) -> String {
        return macBookProNames[identifier] ?? identifier
    }

    private static let macBookProNames: [String: String] = [
        "MacBookPro1,1": "MacBook Pro",
        "MacBookPro2,1": "MacBook Pro (Late 2006)",
        "MacBookPro2,2": "MacBook Pro (Mid 2007)",
        "MacBookPro3,1": "MacBook Pro (Mid 2007)",
        "MacBookPro4,1": "MacBook Pro (Early 2008)",
        "MacBookPro5,1": "MacBook Pro (Late 2008)",
        "MacBookPro5,2": "MacBook Pro (Mid 2009)",
        "MacBookPro5,3": "MacBook Pro (Mid 2009)",
        "MacBookPro5,4": "MacBook Pro (Mid 2009)",
        "MacBookPro5,5": "MacBook Pro (Mid 2009)",
        "MacBookPro6,1": "MacBook Pro (Mid 2010)",
        "MacBookPro6,2": "MacBook Pro (Mid 2010)",
        "MacBookPro7,1": "MacBook Pro (Mid 2010)",
        "MacBookPro8,1": "MacBook Pro (Early 2011)",
        "MacBookPro8,2": "MacBook Pro (Early 2011)",
        "MacBookPro8,3": "MacBook Pro (Early 2011)",
        "MacBookPro9,1": "MacBook Pro (Mid 2012)",
        "MacBookPro9,2": "MacBook Pro (Mid 2012)",
        "MacBookPro10,1": "MacBook Pro (Mid 2012)",
        "MacBookPro10,2": "MacBook Pro (Mid 2012)",
        "MacBookPro11,1": "MacBook Pro (Late 2013)",
        "MacBookPro11,2": "MacBook Pro (Late 2013)",
        "MacBookPro11,3": "MacBook Pro (Late 2013)",
        "MacBookPro11,4": "MacBook Pro (Late 2013)",
        "MacBookPro11,5": "MacBook Pro (Mid 2014)",
        "MacBookPro12,1": "MacBook Pro (Early 2015)",
        "MacBookPro13,1": "MacBook Pro (Early 2015)",
        "MacBookPro13,2": "MacBook Pro (Early 2015)",
        "MacBookPro13,3": "MacBook Pro (Early 2015)",
        "MacBookPro14,1": "MacBook Pro (Mid 2015)",
        "MacBookPro14,2": "MacBook Pro (Mid 2015)",
        "MacBookPro14,3": "MacBook Pro (Mid 2015)",
        "MacBookPro15,1": "MacBook Pro (Late 2016)",
        "MacBookPro15,2": "MacBook Pro (Late 2016)",
        "MacBookPro15,3": "MacBook Pro (Late 2016)",
        "MacBookPro15,4": "MacBook Pro (Late 2016)",
        "MacBookPro16,1": "MacBook Pro (Mid 2017)",
        "MacBookPro16,2": "MacBook Pro (Mid 2017)",
        "MacBookPro16,3": "MacBook Pro (Mid 2017)",
        "MacBookPro16,4": "MacBook Pro (Mid 2017)",
        "MacBookPro17,1": "MacBook Pro (Mid 2018)",
        "MacBookPro18,1": "MacBook Pro (Mid 2018)",
        "MacBookPro18,2": "MacBook Pro (Mid 2018)",
        "MacBookPro18,3": "MacBook Pro (Mid 2018)",
        "MacBookPro18,4": "MacBook Pro (Mid 2018)",
        "MacBookPro19,1": "MacBook Pro (Mid 2019)",
        "MacBookPro19,2": "MacBook Pro (Mid 2019)",
        "MacBookPro19,3": "MacBook Pro (Mid 2019)",
        "MacBookPro19,4": "MacBook Pro (Mid 2019)",
        "MacBookPro19,5": "MacBook Pro (Mid 2019)",
        "MacBookPro19,6": "MacBook Pro (Mid 2019)",
        "MacBookPro20,1": "MacBook Pro (Mid 2020)",
        "MacBookPro20,2": "MacBook Pro (Mid 2020)",
        "MacBookPro20,3": "MacBook Pro (Mid 2020)",
        "MacBookPro20,4": "MacBook Pro (Mid 2020)",
        "MacBookPro21,1": "MacBook Pro (Mid 2021)",
        "MacBookPro21,2": "MacBook Pro (Mid 2021)",
        "MacBookPro21,3": "MacBook Pro (Mid 2021)",
        "MacBookPro21,4": "MacBook Pro (Mid 2021)",
        "MacBookPro22,1": "MacBook Pro (Mid 2022)",
        "MacBookPro22,2": "MacBook Pro (Mid 2022)",
        "MacBookPro22,3": "MacBook Pro (Mid 2022)",
        "MacBookPro22,4": "MacBook Pro (Mid 2022)",
        "MacBookPro23,1": "MacBook Pro (Mid 2023)",
        "MacBookPro23,2": "MacBook Pro (Mid 2023)",
        "MacBookPro23,3": "MacBook Pro (Mid 2023)",
        "MacBookPro23,4": "MacBook Pro (Mid 2023)",
        "MacBookPro24,1": "MacBook Pro (Mid 2024)",
        "MacBookPro24,2": "MacBook Pro (Mid 2024)",
        "MacBookPro24,3": "MacBook Pro (Mid 2024)",
        "MacBookPro24,4": "MacBook Pro (Mid 2024)"
    ]

    // MARK: - iMac Names
    private static func getiMacName(for identifier: String) -> String {
        return iMacNames[identifier] ?? identifier
    }

    private static let iMacNames: [String: String] = [
        "iMac1,1": "iMac",
        "iMac2,1": "iMac (Early 2006)",
        "iMac3,1": "iMac (Mid 2006)",
        "iMac4,1": "iMac (Late 2006)",
        "iMac4,2": "iMac (Mid 2007)",
        "iMac5,1": "iMac (Mid 2007)",
        "iMac5,2": "iMac (Mid 2007)",
        "iMac6,1": "iMac (Late 2006)",
        "iMac7,1": "iMac (Mid 2007)",
        "iMac8,1": "iMac (Early 2008)",
        "iMac8,2": "iMac (Early 2008)",
        "iMac9,1": "iMac (Early 2009)",
        "iMac9,2": "iMac (Early 2009)",
        "iMac10,1": "iMac (Late 2009)",
        "iMac10,2": "iMac (Late 2009)",
        "iMac11,1": "iMac (Mid 2010)",
        "iMac11,2": "iMac (Mid 2010)",
        "iMac11,3": "iMac (Mid 2010)",
        "iMac12,1": "iMac (Mid 2011)",
        "iMac12,2": "iMac (Mid 2011)",
        "iMac13,1": "iMac (Late 2012)",
        "iMac13,2": "iMac (Late 2012)",
        "iMac13,3": "iMac (Late 2012)",
        "iMac14,1": "iMac (Mid 2013)",
        "iMac14,2": "iMac (Mid 2013)",
        "iMac14,3": "iMac (Mid 2013)",
        "iMac14,4": "iMac (Mid 2013)",
        "iMac15,1": "iMac (Mid 2014)",
        "iMac15,2": "iMac (Mid 2014)",
        "iMac16,1": "iMac (Late 2014)",
        "iMac16,2": "iMac (Late 2014)",
        "iMac17,1": "iMac (Late 2015)",
        "iMac18,1": "iMac (Late 2015)",
        "iMac18,2": "iMac (Late 2015)",
        "iMac18,3": "iMac (Late 2015)",
        "iMac19,1": "iMac (Late 2015)",
        "iMac19,2": "iMac (Late 2015)",
        "iMac20,1": "iMac (Mid 2020)",
        "iMac20,2": "iMac (Mid 2020)",
        "iMac21,1": "iMac (Mid 2021)",
        "iMac21,2": "iMac (Mid 2021)",
        "iMac22,1": "iMac (Mid 2022)",
        "iMac22,2": "iMac (Mid 2022)",
        "iMac23,1": "iMac (Mid 2023)",
        "iMac23,2": "iMac (Mid 2023)",
        "iMac24,1": "iMac (Mid 2024)",
        "iMac24,2": "iMac (Mid 2024)"
    ]

    // MARK: - Mac Pro Names
    private static func getMacProName(for identifier: String) -> String {
        return macProNames[identifier] ?? identifier
    }

    private static let macProNames: [String: String] = [
        "MacPro1,1": "Mac Pro",
        "MacPro2,1": "Mac Pro (Early 2008)",
        "MacPro3,1": "Mac Pro (Early 2008)",
        "MacPro4,1": "Mac Pro (Early 2009)",
        "MacPro5,1": "Mac Pro (Mid 2010)",
        "MacPro6,1": "Mac Pro (Late 2013)",
        "MacPro7,1": "Mac Pro (Mid 2019)",
        "MacPro8,1": "Mac Pro (Mid 2023)"
    ]

    // MARK: - Mac mini Names
    private static func getMacminiName(for identifier: String) -> String {
        return macminiNames[identifier] ?? identifier
    }

    private static let macminiNames: [String: String] = [
        "Macmini1,1": "Mac mini",
        "Macmini2,1": "Mac mini (Early 2009)",
        "Macmini3,1": "Mac mini (Late 2009)",
        "Macmini4,1": "Mac mini (Mid 2010)",
        "Macmini5,1": "Mac mini (Mid 2011)",
        "Macmini5,2": "Mac mini (Mid 2011)",
        "Macmini5,3": "Mac mini (Mid 2011)",
        "Macmini6,1": "Mac mini (Late 2012)",
        "Macmini6,2": "Mac mini (Late 2012)",
        "Macmini7,1": "Mac mini (Late 2014)",
        "Macmini8,1": "Mac mini (Late 2018)",
        "Macmini9,1": "Mac mini (Late 2020)",
        "Macmini10,1": "Mac mini (Mid 2021)",
        "Macmini11,1": "Mac mini (Mid 2022)",
        "Macmini12,1": "Mac mini (Mid 2023)",
        "Macmini12,2": "Mac mini (M3, 2023)"
    ]

    // MARK: - Mac Names (Studio, Pro Apple Silicon)
    private static func getMacName(for identifier: String) -> String {
        switch identifier {
        case "Mac13,1": return "Mac Studio (Mid 2022)"
        case "Mac13,2": return "Mac Studio (Mid 2022)"
        case "Mac14,1": return "Mac Studio (Mid 2023)"
        case "Mac14,2": return "Mac Studio (Mid 2023)"
        case "Mac14,8": return "Mac Pro (Mid 2023)"
        default: return identifier
        }
    }

    // MARK: - HomePod Names
    private static func getHomePodName(for identifier: String) -> String {
        switch identifier {
        case "AudioAccessory1,1": return "HomePod"
        case "AudioAccessory1,2": return "HomePod"
        case "AudioAccessory2,1": return "HomePod mini"
        case "AudioAccessory5,1": return "HomePod (2nd generation)"
        case "AudioAccessory6,1": return "HomePod mini (2nd generation)"
        default: return identifier
        }
    }

    // MARK: - Apple TV Names
    private static func getAppleTVName(for identifier: String) -> String {
        return appleTVNames[identifier] ?? identifier
    }

    private static let appleTVNames: [String: String] = [
        "AppleTV1,1": "Apple TV (1st generation)",
        "AppleTV2,1": "Apple TV (2nd generation)",
        "AppleTV3,1": "Apple TV (3rd generation)",
        "AppleTV3,2": "Apple TV (3rd generation)",
        "AppleTV5,3": "Apple TV (4th generation)",
        "AppleTV6,2": "Apple TV 4K (1st generation)",
        "AppleTV11,1": "Apple TV 4K (2nd generation)",
        "AppleTV14,1": "Apple TV 4K (3rd generation)",
        "AppleTV14,2": "Apple TV 4K (3rd generation)",
        "AppleTV15,1": "Apple TV 4K (4th generation)",
        "AppleTV15,2": "Apple TV 4K (4th generation)"
    ]

    // MARK: - Vision Pro Names
    private static func getVisionProName(for identifier: String) -> String {
        switch identifier {
        case "RealityDevice14,1": return "Apple Vision Pro"
        case "RealityDevice14,2": return "Apple Vision Pro"
        default: return identifier
        }
    }
}
