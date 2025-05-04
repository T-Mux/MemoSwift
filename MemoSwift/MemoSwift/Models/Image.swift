import Foundation
import CoreData

@objc(Image)
public class Image: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var data: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: Note?
    
    public var wrappedID: UUID {
        id ?? UUID()
    }
    
    public var wrappedData: Data {
        data ?? Data()
    }
    
    public var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
}

extension Image {
    // 便利方法：创建新图片
    static func createImage(withData data: Data, in context: NSManagedObjectContext) -> Image {
        let newImage = Image(context: context)
        newImage.id = UUID()
        newImage.data = data
        newImage.createdAt = Date()
        return newImage
    }
} 