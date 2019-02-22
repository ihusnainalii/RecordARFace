//
//  RARFObject.swift
//  RecordARFace
//
//  Created by 永田大祐 on 2019/01/06.
//

import ARKit
import UIKit

@available(iOS 11.0, *)
protocol ARSCNDelegate: ARSCNViewDelegate {
    var resource: UIColor { get set }
    var contentNode: SCNNode? { get set }
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode?
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor)
}


@available(iOS 11.0, *)
final class RARFObject: NSObject, ARSessionDelegate {

    public var indexNumber = 0

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.frame = UIScreen.main.bounds
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RARFCell")
        return tableView
    }()

    lazy var arscnView: ARSCNView = {
        let arscnView = ARSCNView()
        arscnView.automaticallyUpdatesLighting = true
        arscnView.frame = UIScreen.main.bounds
        arscnView.delegate = self
        arscnView.session.delegate = self
        arscnView.frame = UIScreen.main.bounds
        return arscnView
    }()

    private lazy var eView: UIView = {
        let eView = UIView()
        eView.frame = CGRect(x: 0,y: 0 ,width:25 ,height:25)
        eView.layer.cornerRadius = eView.frame.height/2
        return eView
    }()

    private var screenNode: SCNNode = {
        let screenNode = SCNPlane(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        screenNode.firstMaterial?.isDoubleSided = true
        return SCNNode(geometry: screenNode)
    }()

    private var nodeFace = SCNNode()
    private var phoneNode: SCNNode = SCNNode()
    private var eyeData: RARFEyeData?
    private var texturedFace: RARFTexturedFace?
    private var key: RARFNumberKeyboardView = RARFNumberKeyboardView()


    override init() {
        super.init()

        arscnView.addSubview(eView)
        arscnView.addSubview(tableView)
        tableView.addSubview(self.key)
        key.originTextField(rect: self.eView.frame)
        Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
    }

    @objc func timerUpdate() { key.originTextField(rect: self.eView.frame) }

    func resetTracking() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arscnView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

    }
        
    func texturedFace(color: UIColor) {
        resetTracking()
        texturedFace = RARFTexturedFace(resource: color)
    }

    func eyeTracking(color: UIColor) {
        #if targetEnvironment(simulator)
        #else
        tableView.isHidden = false
        tableView.delegate = self
        tableView.dataSource = self
        eView = RARFFlameView(eView: eView, color: color).eViews
        eyeData = RARFEyeData()
        arscnView.scene.rootNode.addChildNode(eyeData!)
        arscnView.scene.rootNode.addChildNode(phoneNode)
        phoneNode.geometry?.firstMaterial?.isDoubleSided = true
        phoneNode.addChildNode(screenNode)
        resetTracking()
        #endif
    }
}

// MARK: ARSCNViewDelegate
@available(iOS 11.0, *)
extension RARFObject: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

        guard texturedFace?.renderer(renderer, nodeFor: anchor) == nil else {
            guard let contentNode = texturedFace?.renderer(renderer, nodeFor: anchor) else { return }

            nodeFace = contentNode
            node.addChildNode(contentNode)
            return
        }
        guard let contentNode = eyeData?.renderer(renderer, nodeFor: anchor) else { return }
        nodeFace = contentNode
        node.addChildNode(contentNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard texturedFace?.contentNode == nil else {
            texturedFace?.renderer(renderer, didUpdate: nodeFace, for: anchor)
            return
        }
        eyeData?.transform = node.transform
        eyeData?.renderer(renderer, didUpdate: node, for: anchor)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

        guard eyeData?.contentNode == nil else {
            if let arscnView = arscnView.pointOfView { phoneNode.transform = arscnView.transform }
            let options : [String: Any] = [SCNHitTestOption.backFaceCulling.rawValue: false,
                                           SCNHitTestOption.searchMode.rawValue: 1,
                                           SCNHitTestOption.ignoreChildNodes.rawValue : false,
                                           SCNHitTestOption.ignoreHiddenNodes.rawValue : false]

            let leftEye = phoneNode.hitTestWithSegment (
                from: phoneNode.convertPosition(eyeData!.leftEye.worldPosition, from: nil),
                to:  phoneNode.convertPosition(eyeData!.leftEyeEnd.worldPosition, from: nil),
                options: options)

            let rightEye = phoneNode.hitTestWithSegment (
                from: phoneNode.convertPosition(eyeData!.rightEye.worldPosition, from: nil),
                to:  phoneNode.convertPosition(eyeData!.rightEyeEnd.worldPosition, from: nil),
                options: options)

            if !leftEye.isEmpty && !rightEye.isEmpty {
                guard let coords = eyeData?.eyePosition(leftEye[0], secondResult: rightEye[0]) else { return }
                DispatchQueue.main.sync {
                    self.eView.frame.origin = CGPoint(x: CGFloat(coords.x), y: CGFloat(coords.y))
                }
            }
            return
        }
    }
}

// MARK: UITableViewDataSource, UITableViewDelegate
@available(iOS 11.0, *)
extension RARFObject: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RARFCell", for: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return indexNumber
    }
}

