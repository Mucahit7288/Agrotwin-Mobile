package com.agrotwin.backend.controller;

import com.agrotwin.backend.entity.PriceForecast;
import com.agrotwin.backend.service.PriceForecastService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/price-forecasts")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class PriceForecastController {

    private final PriceForecastService priceForecastService;

    @GetMapping
    public ResponseEntity<List<PriceForecast>> getAll() {
        return ResponseEntity.ok(priceForecastService.getAll());
    }

    @GetMapping("/latest")
    public ResponseEntity<PriceForecast> getLatest() {
        return priceForecastService.getLatest()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/pahali")
    public ResponseEntity<List<PriceForecast>> getPahaliSaatler() {
        return ResponseEntity.ok(priceForecastService.getPahaliSaatler());
    }

    @GetMapping("/ucuz")
    public ResponseEntity<List<PriceForecast>> getUcuzSaatler() {
        return ResponseEntity.ok(priceForecastService.getUcuzSaatler());
    }

    @GetMapping("/{id}")
    public ResponseEntity<PriceForecast> getById(@PathVariable Long id) {
        return priceForecastService.getById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<PriceForecast> create(@RequestBody PriceForecast priceForecast) {
        return ResponseEntity.ok(priceForecastService.save(priceForecast));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        priceForecastService.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
