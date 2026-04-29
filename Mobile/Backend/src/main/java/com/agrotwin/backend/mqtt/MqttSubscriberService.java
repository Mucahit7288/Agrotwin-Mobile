package com.agrotwin.backend.mqtt;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.eclipse.paho.client.mqttv3.*;
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import org.springframework.stereotype.Service;
import com.agrotwin.backend.entity.SensorLog;
import com.agrotwin.backend.service.SensorLogService;

@Slf4j
@Service
@RequiredArgsConstructor
public class MqttSubscriberService implements MqttCallback {

    private static final String BROKER_URL   = "tcp://localhost:1883";
    private static final String CLIENT_ID    = "spring-boot-subscriber";
    private static final String TOPIC        = "topic_sensorler";
    private static final int    QOS          = 1;

    private final SensorLogService sensorLogService;
    private final ObjectMapper     objectMapper;

    private MqttClient mqttClient;

    // ------------------------------------------------------------------ //
    //  Bağlantı & Abonelik                                                //
    // ------------------------------------------------------------------ //

    @PostConstruct
    public void connect() {
        try {
            mqttClient = new MqttClient(BROKER_URL, CLIENT_ID, new MemoryPersistence());
            mqttClient.setCallback(this);
            mqttClient.connect(buildConnectOptions());
            mqttClient.subscribe(TOPIC, QOS);
            log.info("MQTT broker'a bağlanıldı ve '{}' kanalına abone olundu.", TOPIC);
        } catch (MqttException e) {
            log.error("MQTT bağlantısı kurulamadı: {}", e.getMessage(), e);
            closeQuietly(mqttClient);
            mqttClient = null;
        }
    }

    @PreDestroy
    public void disconnect() {
        if (mqttClient == null) {
            return;
        }
        try {
            if (mqttClient.isConnected()) {
                mqttClient.disconnect();
            }
            mqttClient.close();
        } catch (MqttException e) {
            log.warn("MQTT kapatılırken hata: {}", e.getMessage());
        } finally {
            mqttClient = null;
        }
    }

    private static void closeQuietly(MqttClient client) {
        if (client == null) {
            return;
        }
        try {
            client.close();
        } catch (MqttException ignored) {
            // ignore
        }
    }

    private MqttConnectOptions buildConnectOptions() {
        MqttConnectOptions options = new MqttConnectOptions();
        options.setAutomaticReconnect(true);   // kopma durumunda otomatik yeniden bağlan
        options.setCleanSession(true);
        options.setConnectionTimeout(30);
        options.setKeepAliveInterval(60);
        return options;
    }

    // ------------------------------------------------------------------ //
    //  MqttCallback implementasyonu                                       //
    // ------------------------------------------------------------------ //

    /** Gelen mesajı parse edip veritabanına kaydeder. */
    @Override
    public void messageArrived(String topic, MqttMessage message) {
        String payload = new String(message.getPayload());
        log.debug("Mesaj alındı [{}]: {}", topic, payload);
        try {
            SensorLog sensorLog = objectMapper.readValue(payload, SensorLog.class);
            sensorLogService.save(sensorLog);
            log.info("SensorLog kaydedildi: {}", sensorLog);
        } catch (Exception e) {
            log.error("Mesaj işlenirken hata oluştu. Payload: '{}' | Hata: {}", payload, e.getMessage(), e);
        }
    }

    /** Bağlantı koptuğunda çağrılır; setAutomaticReconnect(true) yeniden bağlanmayı üstlenir. */
    @Override
    public void connectionLost(Throwable cause) {
        log.warn("MQTT bağlantısı kesildi: {}. Otomatik yeniden bağlanma deneniyor…", cause.getMessage());
    }

    /** Mesaj iletimi tamamlandığında çağrılır (QoS 1/2 için geçerli). */
    @Override
    public void deliveryComplete(IMqttDeliveryToken token) {
        log.debug("Mesaj iletimi tamamlandı. Token: {}", token.getMessageId());
    }
}