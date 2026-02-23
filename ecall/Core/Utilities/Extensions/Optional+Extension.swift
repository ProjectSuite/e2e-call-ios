extension Optional where Wrapped: RangeReplaceableCollection {
    /// Returns the wrapped collection or an empty one if nil
    var defaultValue: Wrapped {
        return self ?? Wrapped()
    }
}

extension Optional where Wrapped == String {
    /// Returns the wrapped collection or an empty one if nil
    var defaultValue: String {
        return self ?? ""
    }
}

extension Optional where Wrapped == Int {
    /// Returns the wrapped collection or an empty one if nil
    var defaultValue: Int {
        return self ?? 0
    }
}

extension Optional where Wrapped == Double {
    /// Returns the wrapped collection or an empty one if nil
    var defaultValue: Double {
        return self ?? 0.0
    }
}
