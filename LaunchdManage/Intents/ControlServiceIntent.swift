import AppIntents
import Foundation

enum ShortcutsServiceAction: String, AppEnum {
    case load
    case unload
    case start
    case stop
    case enable
    case disable
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Service Action"
    }
    
    static var caseDisplayRepresentations: [ShortcutsServiceAction: DisplayRepresentation] {
        [
            .load: DisplayRepresentation(title: "Load"),
            .unload: DisplayRepresentation(title: "Unload"),
            .start: DisplayRepresentation(title: "Start"),
            .stop: DisplayRepresentation(title: "Stop"),
            .enable: DisplayRepresentation(title: "Enable"),
            .disable: DisplayRepresentation(title: "Disable")
        ]
    }
}

struct ControlServiceIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Control launchd Service"
    }
    
    static var description: IntentDescription? {
        "Perform actions like load, unload, start, or stop on a selected service."
    }
    
    @Parameter(title: "Service")
    var service: ShortcutsJobEntity
    
    @Parameter(title: "Action")
    var action: ShortcutsServiceAction
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let discovery = JobDiscoveryService.shared
        let jobs = await discovery.discoverAllJobs()
        
        guard let job = jobs.first(where: { $0.label == service.id }) else {
            throw NSError(
                domain: "ControlServiceIntent",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Service '\(service.id)' not found.")]
            )
        }
        
        let launchctl = LaunchctlService.shared
        
        switch action {
        case .load:
            try await launchctl.loadService(plistURL: job.plistURL, domain: job.category.domainTarget)
        case .unload:
            try await launchctl.unloadService(domain: job.category.domainTarget, label: job.label)
        case .start:
            try await launchctl.kickstartService(domain: job.category.domainTarget, label: job.label)
        case .stop:
            try await launchctl.sendSignal(15, domain: job.category.domainTarget, label: job.label)
        case .enable:
            try await launchctl.enableService(domain: job.category.domainTarget, label: job.label)
        case .disable:
            try await launchctl.disableService(domain: job.category.domainTarget, label: job.label)
        }
        
        let successMessage = String(localized: "Successfully executed \(action.rawValue) on \(job.label).")
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: successMessage)))
    }
}
