import AppIntents
import Foundation

struct ListServicesIntent: AppIntent {
    static var title: LocalizedStringResource {
        "List launchd Services"
    }
    
    static var description: IntentDescription? {
        "Retrieve all launchd services registered in the system."
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ShortcutsJobEntity]> {
        let discovery = JobDiscoveryService.shared
        let jobs = await discovery.discoverAllJobs()
        await discovery.enrichWithStatus(jobs)
        
        let entities = jobs.map { job in
            ShortcutsJobEntity(
                id: job.label,
                label: job.label,
                category: job.category.displayName,
                status: job.status.displayText
            )
        }
        
        return .result(value: entities)
    }
}
