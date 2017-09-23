//
//  main.swift
//  ResourceKit
//
//  Created by Hirose.Yudai on 2016/01/27.
//  Copyright © 2016年 Hirose.Yudai. All rights reserved.
//

import Foundation
private let RESOURCE_FILENAME = "Resource.generated.swift"
private let env = ProcessInfo().environment
let debug = env["DEBUG"] != nil
let defaultAccessControl: String = "public"
let accessControl = defaultAccessControl

private func extractGenerateDir() -> String? {
    return ProcessInfo
        .processInfo
        .arguments
        .flatMap { arg in
            guard let range = arg.range(of: "-p ") else {
                return nil
            }
            return arg.substring(from: range.upperBound)
        }
        .last
}

if !debug {
    do {
        try Environment.verifyUseEnvironment()
    } catch {
        exit(1)
    }
}

let debugOutputPath = env["DEBUG_OUTPUT_PATH"]
let outputPath = debugOutputPath ?? extractGenerateDir() ?? Environment.SRCROOT.element
let config: Config = Config()

do {
    let outputUrl = URL(fileURLWithPath: outputPath)
    var resourceValue: AnyObject?
    try (outputUrl as NSURL).getResourceValue(&resourceValue, forKey: URLResourceKey.isDirectoryKey)
    
    let writeUrl: URL = outputUrl.appendingPathComponent(RESOURCE_FILENAME, isDirectory: false)

    let projectFilePath = env["DEBUG_PROJECT_FILE_PATH"] != nil ? URL(fileURLWithPath: env["DEBUG_PROJECT_FILE_PATH"]!) : Environment.PROJECT_FILE_PATH.path
    let projectTarget = env["DEBUG_TARGET_NAME"] ?? Environment.TARGET_NAME.element
    let parser = try ProjectResourceParser(xcodeURL: projectFilePath, target: projectTarget)
    let paths = ProjectResource.shared.paths
    
    paths
        .filter { $0.pathExtension == "storyboard" }
        .forEach { let _ = try? StoryboardParser(url: $0) }
    
    paths
        .filter { $0.pathExtension == "xib" }
        .forEach { let _ = try? XibPerser(url: $0) }
    
    let importsContent = ImportOutputImpl(writeUrl: writeUrl).declaration
    
    let viewControllerContent = ProjectResource.shared.viewControllers
        .flatMap { $0.declaration }
        .joined(separator: newLine)
    
    let tableViewCellContent: String
    let collectionViewCellContent: String
    
    if config.reusable.identifier {
        tableViewCellContent = ProjectResource.shared.tableViewCells
            .flatMap { $0.declaration }
            .joined(separator: newLine)
        
        collectionViewCellContent = ProjectResource.shared.collectionViewCells
            .flatMap { $0.declaration }
            .joined(separator: newLine)
        
    } else {
        tableViewCellContent = ""
        collectionViewCellContent = ""
    }
    
    let xibContent: String
    if config.nib.xib {
        xibContent = ProjectResource.shared.xibs
            .flatMap { $0.declaration }
            .joined(separator: newLine)
    } else {
        xibContent = ""
    }
    
    let imageContent = try ImageTranslator().translate(
        for: (
            assets: ImageAssetRepositoryImpl().load(),
            resources: ImageResourcesRepositoryImpl().load())
        )
        .declaration
    
    let stringContent: String
    
    if config.string.localized {
        stringContent = try LocalizedStringTranslator()
            .translate(
                for: LocalizedStringRepositoryImpl(urls: ProjectResource.shared.localizablePaths).load()
            )
            .declaration
    } else {
        stringContent = ""
    }
    
    let content = (
        Header
            + importsContent + newLine
            + ExtensionsOutputImpl().reusableProtocolContent + newLine
            + ExtensionsOutputImpl().xibProtocolContent + newLine
            + ExtensionsOutputImpl().tableViewExtensionContent + newLine
            + ExtensionsOutputImpl().collectionViewExtensionContent + newLine
            + viewControllerContent + newLine
            + tableViewCellContent + newLine
            + collectionViewCellContent + newLine
            + xibContent + newLine
            + imageContent + newLine
            + stringContent + newLine
    )
    
    func write(_ code: String, fileURL: URL) throws {
        try code.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
    }
    
    try write(content, fileURL: writeUrl)
} catch {
    if let e = error as? ResourceKitErrorType {
        print(e.description())
        
    } else {
        print(error)
    }
    
    exit(3)
}
