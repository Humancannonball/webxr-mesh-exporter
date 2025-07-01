#!/bin/bash

# PM2 Management Script for WebXR Mesh Exporter
# Handles PM2 operations that require sudo privileges for port 80

APP_NAME="webxr-mesh-exporter"

case "$1" in
    start)
        echo "🚀 Starting $APP_NAME..."
        sudo pm2 start config/ecosystem.config.js --env production
        ;;
    stop)
        echo "🛑 Stopping $APP_NAME..."
        sudo pm2 stop $APP_NAME
        ;;
    restart)
        echo "🔄 Restarting $APP_NAME..."
        sudo pm2 restart $APP_NAME
        ;;
    status)
        echo "📊 Status of $APP_NAME:"
        sudo pm2 status $APP_NAME
        ;;
    logs)
        echo "📝 Logs for $APP_NAME:"
        sudo pm2 logs $APP_NAME
        ;;
    save)
        echo "💾 Saving PM2 configuration..."
        sudo pm2 save
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|save}"
        echo ""
        echo "Available commands:"
        echo "  start   - Start the application"
        echo "  stop    - Stop the application"
        echo "  restart - Restart the application"
        echo "  status  - Show application status"
        echo "  logs    - Show application logs"
        echo "  save    - Save PM2 configuration"
        exit 1
        ;;
esac
