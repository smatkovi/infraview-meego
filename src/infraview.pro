TEMPLATE = app
TARGET = infraview
QT += declarative network

CONFIG += qdeclarative-boostable

VERSION_STRING = 0.1.0
DEFINES += INFRAVIEW_VERSION=\\\"$$VERSION_STRING\\\"

SOURCES += main.cpp helfer.cpp
HEADERS += helfer.h

target.path = /opt/infraview/bin
INSTALLS += target
