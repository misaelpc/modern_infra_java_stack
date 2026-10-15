package demo;

import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@Path("/")
public class DemoResource {

    private static final Path BANNER = Path.of("/secrets/banner/banner.txt");

    private final String mongoRootPassword;

    private final String mongoUri;

    private final String etiqueta;

    @Inject
    public DemoResource(
            @ConfigProperty(name = "mongo-root-password")
            final String mongoRootPassword,
            @ConfigProperty(name = "mongo-uri") final String mongoUri,
            @ConfigProperty(name = "etiqueta") final String etiqueta) {
        this.mongoRootPassword = mongoRootPassword;
        this.mongoUri = mongoUri;
        this.etiqueta = etiqueta;
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> estado() {
        Map<String, String> cuerpo = new LinkedHashMap<>();
        cuerpo.put("mongo-root-password", mongoRootPassword);
        cuerpo.put("mongo-connection-string", mongoUri);
        cuerpo.put("etiqueta", etiqueta);
        cuerpo.put("banner", banner());
        return cuerpo;
    }

    private static String banner() {
        try {
            return Files.readString(BANNER).trim();
        } catch (IOException exception) {
            throw new UncheckedIOException(
                    "No se pudo leer " + BANNER, exception);
        }
    }
}
