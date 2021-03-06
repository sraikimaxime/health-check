expect = require('chai').expect
express = require 'express'
request = require 'supertest'

module = require('../../main/src/module')
mongo = require('../mongo')
elasticsearch = require('../elasticsearch')
postgres = require('../postgres')

app = null
serverExpress = null

port = 9876
url  = 'http://localhost:' + port

startServerExpress = (callback = ( -> return )) ->
  app = express()

  mongo.init ->
    postgres.postgresClient.connect()
    serverExpress = app.listen port, callback

    app.use module
      mongo:
        client: mongo.mongoDb
      elasticsearch:
        client: elasticsearch.elasticClient
      postgres:
        client: postgres.postgresClient
      custom:
        hello: (done) ->
          done null, 'hello response'

stopServerExpress = (callback = ( -> return )) ->
  serverExpress.close callback
  mongo.mongoDb.close()

describe 'Express module', ->
  agent = null

  before (done) ->
    startServerExpress done
    agent = request.agent app

  after (done) ->
    stopServerExpress done

  describe 'GET /api/health-check', ->
    it 'should respond 200 code', (done) ->
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.statusCode).to.eql 200
        done()

    it 'should return the uptime', (done) ->
      agent.get '/api/health-check'
      .end (err, res) ->
        uptime = res.body.uptime
        setTimeout ->
          agent.get '/api/health-check'
          .end (err2, res2) ->
            expect(res2.body.uptime).to.not.eql uptime
            done()
        , 1000

    it 'should detect connection to mongodb', (done) ->
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.body.mongo).to.eql {status: 'ok'}
        done()

    it 'should not dectect any connection to mongodb', (done) ->
      mongo.mongoDb.close()
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.body.mongo).to.eql {status: 'ko'}
        done()

    it 'should detect connection to postgres', (done) ->
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.body.postgres).to.eql {status: 'ok'}
        done()

    it 'should not detect any connection to postgres', (done) ->
      postgres.postgresClient.end()
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.body.postgres).to.eql {status: 'ko'}
        done()

    it 'should detect connection to elasticsearch', (done) ->
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.body.elasticsearch.status).to.eql 'ok'
        done()

    it 'should display custom checks', (done) ->
      agent.get '/api/health-check'
      .end (err, res) ->
        expect(res.body.hello).to.eql 'hello response'
        done()
