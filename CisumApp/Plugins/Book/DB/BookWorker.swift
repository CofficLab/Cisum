import Foundation
import OSLog

class BookWorker {
    private let taskQueue = DispatchQueue(label: "com.bookworker.taskQueue")
    private let db: BookDB
    private var isRunning = false
    
    init(db: BookDB) {
        self.db = db
    }
    
    func addJob(_ job: any BookJob) {
//        taskQueue.async {
//            job.run(verbose: false)
//        }
    }
    
    func runJobs() {
        guard !isRunning else { return }
        isRunning = true
        
        // Add your jobs here
//        addJob(BookUpdateCoverJob(db: self.db))
        // Add more jobs as needed
        // addJob(AnotherJob(db: self.db))
    }
}

protocol BookJob {
    func run(verbose: Bool)
}
