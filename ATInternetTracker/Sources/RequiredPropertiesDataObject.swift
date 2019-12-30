//
//  RequiredPropertiesDataObject.swift
//  Tracker
//
import Foundation

public enum RequiredPropertiesDataObjectPropertyType: String {
    case string = "s"
    case number = "n"
    case boolean = "b"
    case date = "d"
    case float = "f"
    case arrayString = "a:s"
    case arrayNumber = "a:n"
    case arrayFloat = "a:f"
}

public class RequiredPropertiesDataObject : NSObject {
    
    fileprivate let propertiesSynchronizer = DispatchQueue(label: "PropertiesSynchronizer")
    var properties = [String : Any]()
    var propertiesPrefixMap = [String : String]()
    
    @objc public func set(key: String, value: Any) -> RequiredPropertiesDataObject {
        if let prefix = propertiesPrefixMap[key] {
            self.propertiesSynchronizer.async {
                self.properties[String(format: "%@:%@", prefix, key)] = value
            }
        } else {
            self.propertiesSynchronizer.async {
                self.properties[key] = value
            }
        }
        return self
    }
    
    public func set(key: String, value: Any, propertyType: RequiredPropertiesDataObjectPropertyType) -> RequiredPropertiesDataObject {
        self.propertiesSynchronizer.async {
            self.properties[String(format: "%@:%@", propertyType.rawValue, key)] = value
        }
        return self
    }
    
    @objc public func setAll(obj: [String : Any]) -> RequiredPropertiesDataObject {
        for (k,v) in obj {
            _ = set(key: k, value: v)
        }
        return self
    }
    
    func get(key: String) -> Any? {
        var val : Any? = nil
        self.propertiesSynchronizer.sync {
            val = self.properties[key]
        }
        return val
    }
    
    func copyAll(src: RequiredPropertiesDataObject) -> RequiredPropertiesDataObject {
        for (k,v) in src.properties {
            self.propertiesSynchronizer.async {
                self.properties[k] = v
            }
        }
        return self
    }
}
