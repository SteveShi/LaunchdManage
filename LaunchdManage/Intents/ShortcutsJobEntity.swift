import AppIntents
import Foundation

struct ShortcutsJobEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "launchd Service"
    }
    
    let id: String // label
    let label: String
    let category: String
    let status: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(label)",
            subtitle: "\(category) • \(status)"
        )
    }
    
    static let defaultQuery = ShortcutsJobQuery()
}

struct ShortcutsJobQuery: EntityQuery {
    @MainActor
    func entities(for ids: [String]) async throws -> [ShortcutsJobEntity] {
        let discovery = JobDiscoveryService.shared
        let jobs = await discovery.discoverAllJobs()
        await discovery.enrichWithStatus(jobs)
        
        return jobs.filter { ids.contains($0.label) }.map { job in
            ShortcutsJobEntity(
                id: job.label,
                label: job.label,
                category: job.category.displayName,
                status: job.status.displayText
            )
        }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [ShortcutsJobEntity] {
        let discovery = JobDiscoveryService.shared
        let jobs = await discovery.discoverAllJobs()
        await discovery.enrichWithStatus(jobs)
        
        return jobs.map { job in
            ShortcutsJobEntity(
                id: job.label,
                label: job.label,
                category: job.category.displayName,
                status: job.status.displayText
            )
        }
    }
}
