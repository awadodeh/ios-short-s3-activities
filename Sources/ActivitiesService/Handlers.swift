import Foundation
import Kitura
import SwiftyJSON
import LoggerAPI
import MySQL

// MARK: - Handlers

public class Handlers {
    var connectionPool: MySQLConnectionPool

    public init(connectionPool: MySQLConnectionPool) {
        self.connectionPool = connectionPool
    }

    // MARK: OPTIONS

    public func getOptions(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        response.headers["Access-Control-Allow-Headers"] = "accept, content-type"
        response.headers["Access-Control-Allow-Methods"] = "GET,POST,DELETE,OPTIONS,PUT"
        try response.status(.OK).end()
    }

    // MARK: GET

    public func onGetActivities(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        do {
            if let connection = try connectionPool.getConnection() {
                defer { connectionPool.releaseConnection(connection) }
                try getActivity(withID: nil, connection: connection, response: response)
            } else {
                try response.status(.internalServerError).end()
            }
        }
    }

    public func onGetActivity(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {

        guard let id = request.parameters["id"] else {
            Log.error("Parameters missing")
            try response.status(.badRequest).end()
            return
        }

        do {
            if let connection = try connectionPool.getConnection() {
                defer { connectionPool.releaseConnection(connection) }
                try getActivity(withID: id, connection: connection, response: response)
            } else {
                try response.status(.internalServerError).end()
            }
        }
    }

    private func getActivity(withID id: String? = nil, connection: MySQLConnectionProtocol, response: RouterResponse) throws {
        do {
            if let id = id {
                let result = executeQuery("SELECT * FROM activities WHERE id = \(id)", connection: connection)
                try returnResult(result, response: response)
            } else {
                let result = executeQuery("SELECT * FROM activities", connection: connection)
                try returnResult(result, response: response)
            }
        }
    }

    // MARK: POST

    public func onCreateActivity(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {

        guard let body = request.body, case let .json(json) = body else {
            Log.error("Body contains invalid JSON")
            try response.status(.badRequest).end()
            return
        }

        guard let name = json["name"].string,
            let description = json["description"].string,
            let genre = json["genre"].string,
            let minParticipants = json["min_participants"].int,
            let maxParticipants = json["max_participants"].int else {
                Log.error("Parameters missing")
                try response.status(.badRequest).end()
                return
        }

        let newActivity = Activity(id: nil, name: name, description: description, genre: genre,
            minParticipants: minParticipants, maxParticipants: maxParticipants,
            createdAt: nil, updatedAt: nil)

        do {
            if let connection = try connectionPool.getConnection() {
                defer { connectionPool.releaseConnection(connection) }
                try createNewActivity(newActivity, connection: connection, response: response)
            } else {
                try response.status(.internalServerError).end()
            }
        }
    }

    private func createNewActivity(_ activity: Activity, connection: MySQLConnectionProtocol, response: RouterResponse) throws {
        do {
            let _ = executeQuery("""
                INSERT INTO activities (name, description, genre, min_participants, max_participants)
                VALUES ('\(activity.name!)', '\(activity.description!)', '\(activity.genre!)', \(activity.minParticipants!), \(activity.maxParticipants!))
                """, connection: connection)
            try response.send(json: JSON(["status": 201, "message": "resource created"])).status(.created).end()
        }
    }

    // MARK: PUT

    public func onUpdateActivity(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {

        guard let body = request.body, case let .json(json) = body else {
            Log.error("Body contains invalid JSON")
            try response.status(.badRequest).end()
            return
        }

        guard let id = request.parameters["id"],
            let name = json["name"].string,
            let description = json["description"].string,
            let genre = json["genre"].string,
            let minParticipants = json["min_participants"].int,
            let maxParticipants = json["max_participants"].int else {
                Log.error("Parameters missing")
                try response.status(.badRequest).end()
                return
        }

        let tempActivity = Activity(id: Int(id), name: name, description: description, genre: genre,
            minParticipants: minParticipants, maxParticipants: maxParticipants,
            createdAt: nil, updatedAt: nil)

        do {
            if let connection = try connectionPool.getConnection() {
                defer { connectionPool.releaseConnection(connection) }
                try updateActivity(tempActivity, connection: connection, response: response)
            } else {
                try response.status(.internalServerError).end()
            }
        }
    }

    private func updateActivity(_ activity: Activity, connection: MySQLConnectionProtocol, response: RouterResponse) throws {
        do {
            let _ = executeQuery("""
                UPDATE activities SET name = '\(activity.name!)', description = '\(activity.description!)',
                genre = '\(activity.genre!)', min_participants = \(activity.minParticipants!),
                max_participants = \(activity.maxParticipants!) WHERE id = \(activity.id!)
                """, connection: connection)
            try response.send(json: JSON(["status": 204, "message": "resource updated"])).status(.noContent).end()
        }
    }

    // MARK: DELETE

    public func onDeleteActivity(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {

        guard let id = request.parameters["id"] else {
            Log.error("Parameters missing")
            try response.status(.badRequest).end()
            return
        }

        do {
            if let connection = try connectionPool.getConnection() {
                defer { connectionPool.releaseConnection(connection) }
                try deleteActivityWithID(id, connection: connection, response: response)
            } else {
                try response.status(.internalServerError).end()
            }
        }
    }

    private func deleteActivityWithID(_ id: String, connection: MySQLConnectionProtocol, response: RouterResponse) throws {
        do {
            let _ = executeQuery("DELETE FROM activities WHERE id = \(id)", connection: connection)
            try response.send(json: JSON(["status": 204, "message": "resource deleted"])).status(.noContent).end()
        }
    }

    // MARK: Utility

    private func executeQuery(_ query: String, connection: MySQLConnectionProtocol) -> (MySQLResultProtocol?, error: MySQLError?) {
        let client = MySQLClient(connection: connection)
        return client.execute(query: query)
    }

    private func returnResult(_ result: (MySQLResultProtocol?, error: MySQLError?), response: RouterResponse) throws {

        if let results = result.0 as? MySQLResult {
            let activities = results.toActivities()

            if activities.count > 0 {
                try response.send(json: activities.toJSON()).status(.OK).end()
            } else {
                try response.send(json: JSON([:])).status(.notFound).end()
            }
        } else {
            Log.error(result.1?.localizedDescription ?? "")
            try response.status(.internalServerError).end()
            return
        }
    }
}
