//
//  CodeaProjectViewController.swift
//  SpartsScoresheet
//
//  Created by Jesse Wonder Clark on Friday, February 6, 2026.
//  Copyright © 2019 Jesse Wonder Clark. All rights reserved.
//

import UIKit
import Tools
import RuntimeKit
import CraftKit

class CodeaProjectViewController: CodeaViewController {

    let projectUrl: URL
    
    init(url: URL, addons: [CodeaAddon]) {
        projectUrl = url
        
        let runtime = ThreadedRuntimeViewController(addons: [
            CodeaStandardLibrary(),
            CraftAddon()
        ] + addons)
        
        super.init(runtime: runtime, activityType: "exported-codea-project")
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeRenderer {
            success in
            
            if !success {
                fatalError("Failed to load Codea project")
            }
        }
    }

    func initializeRenderer(completion: @escaping (Bool)->()) {

        guard let project = Project(bundlePath: projectUrl.path) else {
            print("FAILED TO CREATE PROJECT at path:", projectUrl.path)
            completion(false)
            return
        }

        print("PROJECT LOADED:", project.name)
        print("PROJECT PATH:", project.bundlePath)

        runtime.project = project

        runtime.validateProject(project) { valid in
            print("PROJECT VALID:", valid)

            guard valid else {
                completion(false)
                return
            }

            self.runtime.start {
                DispatchQueue.main.async {
                    self.runtime.startAnimation()
                    completion(true)
                }
            }
        }
    }


}

